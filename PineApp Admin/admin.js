// admin.js (compatible with the compat SDK)
firebase.initializeApp(firebaseConfig);

const auth = firebase.auth();
const db = firebase.firestore();
const storage = firebase.storage();

const btnSignIn = document.getElementById('btnSignIn');
const btnSignOut = document.getElementById('btnSignOut');
const authMsg = document.getElementById('authMsg');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const panel = document.getElementById('panel');
const pendingList = document.getElementById('pendingList');
const adminInfo = document.getElementById('adminInfo');
const adminEmailSpan = document.getElementById('adminEmail');

const userTpl = document.getElementById('userCardTpl');

btnSignIn.addEventListener('click', async () => {
  const email = emailInput.value.trim();
  const password = passwordInput.value.trim();
  authMsg.textContent = '';
  try {
    await auth.signInWithEmailAndPassword(email, password);
  } catch (err) {
    authMsg.textContent = 'Sign in failed: ' + err.message;
  }
});

btnSignOut && btnSignOut.addEventListener('click', () => auth.signOut());

auth.onAuthStateChanged(async (user) => {
  if (user) {
    const email = user.email || '';
    if (email.toLowerCase() !== ADMIN_EMAIL.toLowerCase()) {
      authMsg.textContent = 'This account is not authorized as admin.';
      await auth.signOut();
      return;
    }

    // show admin panel
    adminInfo.hidden = false;
    document.getElementById('authSection').hidden = true;
    panel.hidden = false;
    adminEmailSpan.textContent = email;

    loadVerifiedUsers(); // Load only verified users
  } else {
    adminInfo.hidden = true;
    document.getElementById('authSection').hidden = false;
    panel.hidden = true;
    pendingList.innerHTML = '';
  }
});

// Load only users who have verified their email
let unsubscribe = null;
function loadVerifiedUsers() {
  if (unsubscribe) unsubscribe();

  pendingList.innerHTML = 'Loading verified users...';

  unsubscribe = db.collection('users')
    .where('email_verified', '==', true) // Only users who verified email
    .orderBy('created_at', 'desc')
    .onSnapshot(snapshot => {
      if (snapshot.empty) {
        pendingList.innerHTML = '<div class="muted">No verified users found.</div>';
        return;
      }

      pendingList.innerHTML = '';
      snapshot.forEach(doc => {
        const data = doc.data();
        const node = userTpl.content.cloneNode(true);

        node.querySelector('.user-name').textContent = data.name || '(no name)';
        node.querySelector('.user-role').textContent = data.role || '';
        node.querySelector('.user-email').textContent = data.email || '';
        node.querySelector('.license-number').textContent = data.license_number || '—';

        // proofs
        const proofsDiv = node.querySelector('.proofs');
        proofsDiv.innerHTML = '';
        if (data.proof_image) {
          const img = document.createElement('img');
          img.src = data.proof_image;
          img.className = 'proof-img';
          proofsDiv.appendChild(img);
        } else if (data.proof_images && Array.isArray(data.proof_images)) {
          data.proof_images.forEach(url => {
            const img = document.createElement('img');
            img.src = url;
            img.className = 'proof-img';
            proofsDiv.appendChild(img);
          });
        } else {
          proofsDiv.textContent = 'No proofs uploaded.';
        }

        // actions
        const approveBtn = node.querySelector('.approve-btn');
        const rejectBtn = node.querySelector('.reject-btn');

        // Admin approval optional: just notify user
        approveBtn.addEventListener('click', () => notifyUser(doc.id, 'approved'));
        rejectBtn.addEventListener('click', () => notifyUser(doc.id, 'rejected'));

        pendingList.appendChild(node);
      });
    }, err => {
      pendingList.innerHTML = '<div class="muted">Error loading users: ' + err.message + '</div>';
    });
}

// Notify user of approval/rejection (no email verification required)
async function notifyUser(userDocId, action) {
  if (!confirm(`Are you sure you want to mark this user as ${action}?`)) return;

  try {
    await db.collection('users').doc(userDocId).update({
      status: action,
      notification: `Your account has been ${action} by admin on ${new Date().toLocaleString()}`,
      notification_unread: true,
      verified_by_admin_at: firebase.firestore.FieldValue.serverTimestamp()
    });

    // Add log entry
    await db.collection('admin_logs').add({
      user: userDocId,
      action: action,
      admin: auth.currentUser.email,
      created_at: firebase.firestore.FieldValue.serverTimestamp()
    });

    alert(`User ${action} successfully.`);
  } catch (err) {
    alert('Failed: ' + err.message);
  }
}
