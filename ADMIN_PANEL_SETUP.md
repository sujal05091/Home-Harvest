# 🔧 ADMIN PANEL SETUP GUIDE
## HomeHarvest - Web-Based Admin Dashboard

---

## 📌 OVERVIEW

The **Admin Panel** is a **SEPARATE WEB APPLICATION** (not part of the Flutter mobile app).  
It connects to the **same Firebase project** and allows administrators to:

- ✅ View all users (customers, cooks, riders)
- ✅ **Verify cooks** (approve/reject verification requests)
- ✅ Monitor orders in real-time
- ✅ Manually assign/reassign riders
- ✅ Block/unblock users
- ✅ View analytics and reports

---

## 🛠️ TECH STACK

**Frontend:**
- React.js (or Angular/Vue.js)
- Material-UI / Ant Design
- Firebase SDK (Web)

**Backend:**
- Firebase Admin SDK (Node.js)
- Cloud Functions (optional for advanced logic)

**Database:**
- Same Firestore project as mobile app

---

## 📂 PROJECT STRUCTURE

```
home-harvest-admin/
├── public/
│   └── index.html
├── src/
│   ├── components/
│   │   ├── Sidebar.jsx
│   │   ├── Navbar.jsx
│   │   └── UserCard.jsx
│   ├── pages/
│   │   ├── Dashboard.jsx
│   │   ├── Users.jsx
│   │   ├── CookVerifications.jsx ⭐ MOST IMPORTANT
│   │   ├── Orders.jsx
│   │   └── Analytics.jsx
│   ├── firebase/
│   │   ├── config.js
│   │   └── admin.js
│   ├── App.js
│   └── index.js
├── .env
├── package.json
└── README.md
```

---

## 🔥 FIREBASE CONFIGURATION

### 1. **Enable Firebase Web SDK**

In Firebase Console:
- Go to **Project Settings → General**
- Under "Your apps", click **Add app → Web**
- Register app name: `HomeHarvest Admin`
- Copy config object

Create `src/firebase/config.js`:

```javascript
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
```

---

### 2. **Admin Authentication**

Admin login uses Firebase Auth with custom claims:

**In Firebase Console:**
- Create an admin user manually
- Email: `admin@homeharvest.com`
- Password: (strong password)

**Set Custom Claims (using Firebase Admin SDK or Cloud Function):**

```javascript
// Cloud Function to set admin role
const admin = require('firebase-admin');

exports.setAdminRole = functions.https.onCall(async (data, context) => {
  // Only existing admin can create new admin
  if (!context.auth.token.admin === true) {
    throw new functions.https.HttpsError('permission-denied');
  }
  
  await admin.auth().setCustomUserClaims(data.uid, {admin: true});
  return {message: `Success! ${data.uid} is now admin`};
});
```

**Check admin role in web app:**

```javascript
import { auth } from './firebase/config';
import { onAuthStateChanged } from 'firebase/auth';

onAuthStateChanged(auth, async (user) => {
  if (user) {
    const tokenResult = await user.getIdTokenResult();
    if (tokenResult.claims.admin) {
      console.log('Admin logged in!');
    }
  }
});
```

---

## ⭐ COOK VERIFICATION FEATURE (CRITICAL)

### **Flow:**
1. Cook uploads photos in mobile app
2. Document saved in `cook_verifications` collection with status = PENDING
3. Admin sees verification request in web panel
4. Admin reviews photos and hygiene checklist
5. Admin clicks APPROVE or REJECT
6. On APPROVE: Update `users/{cookId}.verified = true`

---

### **CookVerifications.jsx (React Page)**

```jsx
import React, { useEffect, useState } from 'react';
import { db } from '../firebase/config';
import { collection, query, where, getDocs, updateDoc, doc } from 'firebase/firestore';

function CookVerifications() {
  const [verifications, setVerifications] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPendingVerifications();
  }, []);

  const loadPendingVerifications = async () => {
    try {
      const q = query(
        collection(db, 'cook_verifications'),
        where('status', '==', 'PENDING')
      );
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setVerifications(data);
    } catch (error) {
      console.error('Error loading verifications:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (verification) => {
    try {
      // Update verification status
      await updateDoc(doc(db, 'cook_verifications', verification.id), {
        status: 'APPROVED',
        reviewedAt: new Date(),
        reviewedBy: 'admin@homeharvest.com' // Current admin email
      });

      // ⭐ MOST IMPORTANT: Update user verified status
      await updateDoc(doc(db, 'users', verification.cookId), {
        verified: true
      });

      alert('Cook verified successfully!');
      loadPendingVerifications(); // Reload list
    } catch (error) {
      console.error('Error approving:', error);
      alert('Error: ' + error.message);
    }
  };

  const handleReject = async (verification) => {
    try {
      await updateDoc(doc(db, 'cook_verifications', verification.id), {
        status: 'REJECTED',
        reviewedAt: new Date(),
        reviewedBy: 'admin@homeharvest.com'
      });

      alert('Verification rejected');
      loadPendingVerifications();
    } catch (error) {
      console.error('Error rejecting:', error);
    }
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      <h1>Cook Verifications</h1>
      {verifications.length === 0 ? (
        <p>No pending verifications</p>
      ) : (
        verifications.map(v => (
          <div key={v.id} style={{border: '1px solid #ccc', padding: 20, margin: 10}}>
            <h3>{v.cookName}</h3>
            <p>Email: {v.cookEmail}</p>
            <p>Phone: {v.cookPhone}</p>
            <p>Description: {v.description}</p>
            
            <h4>Kitchen Photos:</h4>
            <div style={{display: 'flex', gap: 10}}>
              {v.images.map((url, i) => (
                <img key={i} src={url} alt={`Kitchen ${i+1}`} 
                     style={{width: 150, height: 150, objectFit: 'cover'}} />
              ))}
            </div>

            <h4>Hygiene Checklist:</h4>
            <ul>
              {Object.entries(v.hygieneChecklist).map(([key, val]) => (
                <li key={key}>
                  {key}: {val ? '✅' : '❌'}
                </li>
              ))}
            </ul>

            <button onClick={() => handleApprove(v)} 
                    style={{backgroundColor: 'green', color: 'white', padding: 10}}>
              ✅ APPROVE
            </button>
            <button onClick={() => handleReject(v)} 
                    style={{backgroundColor: 'red', color: 'white', padding: 10, marginLeft: 10}}>
              ❌ REJECT
            </button>
          </div>
        ))
      )}
    </div>
  );
}

export default CookVerifications;
```

---

## 📊 OTHER ADMIN PAGES

### **Orders.jsx**
```jsx
import { collection, onSnapshot } from 'firebase/firestore';

function Orders() {
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    // Real-time listener
    const unsubscribe = onSnapshot(collection(db, 'orders'), (snapshot) => {
      const data = snapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
      setOrders(data);
    });
    return unsubscribe;
  }, []);

  return (
    <div>
      <h1>All Orders</h1>
      <table>
        <thead>
          <tr>
            <th>Order ID</th>
            <th>Customer</th>
            <th>Cook</th>
            <th>Total</th>
            <th>Status</th>
            <th>Rider</th>
          </tr>
        </thead>
        <tbody>
          {orders.map(order => (
            <tr key={order.id}>
              <td>{order.orderId}</td>
              <td>{order.customerName}</td>
              <td>{order.cookName}</td>
              <td>₹{order.total}</td>
              <td>{order.status}</td>
              <td>{order.assignedRiderName || 'Not assigned'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

---

### **Users.jsx**
```jsx
function Users() {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    const snapshot = await getDocs(collection(db, 'users'));
    setUsers(snapshot.docs.map(doc => ({id: doc.id, ...doc.data()})));
  };

  const blockUser = async (userId) => {
    await updateDoc(doc(db, 'users', userId), {blocked: true});
    loadUsers();
  };

  return (
    <div>
      <h1>All Users</h1>
      {users.map(user => (
        <div key={user.id}>
          <p>{user.name} - {user.role} - {user.email}</p>
          <button onClick={() => blockUser(user.id)}>Block</button>
        </div>
      ))}
    </div>
  );
}
```

---

## 🚀 DEPLOYMENT

### **Option 1: Firebase Hosting**

```bash
npm install -g firebase-tools
firebase login
firebase init hosting
npm run build
firebase deploy --only hosting
```

### **Option 2: Vercel/Netlify**

- Push code to GitHub
- Connect repo to Vercel/Netlify
- Auto-deploy on push

---

## 🔐 SECURITY RULES

Update Firestore rules to allow admin writes:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Cook verifications
    match /cook_verifications/{verificationId} {
      allow read, write: if request.auth != null && request.auth.token.admin == true;
    }
    
    // Users
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId || request.auth.token.admin == true;
    }
    
    // Orders
    match /orders/{orderId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }
  }
}
```

---

## 📝 INSTALLATION STEPS

1. **Create React App:**
```bash
npx create-react-app home-harvest-admin
cd home-harvest-admin
npm install firebase react-router-dom
```

2. **Add Firebase Config:**
Create `src/firebase/config.js` with your Firebase credentials

3. **Create Pages:**
- Copy the code above for CookVerifications.jsx
- Create Orders.jsx, Users.jsx, etc.

4. **Setup Routing:**
```jsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/verifications" element={<CookVerifications />} />
        <Route path="/orders" element={<Orders />} />
        <Route path="/users" element={<Users />} />
      </Routes>
    </BrowserRouter>
  );
}
```

5. **Run:**
```bash
npm start
```

---

## 🎯 KEY POINTS

✅ Admin panel is a **separate web app**  
✅ Uses same Firebase project as mobile app  
✅ Most important feature: **Cook verification approval**  
✅ Real-time order monitoring  
✅ Manual rider assignment (optional)  
✅ User management  

---

## 📞 SUPPORT

For any issues with admin panel setup:
1. Check Firebase console for errors
2. Verify Firebase config is correct
3. Ensure admin custom claims are set
4. Test Firestore rules

---

**Last Updated:** December 20, 2025
