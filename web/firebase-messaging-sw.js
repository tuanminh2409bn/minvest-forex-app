// Import các SDK cần thiết của Firebase (khuyến khích dùng phiên bản ổn định gần đây)
importScripts("https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js");

// Cấu hình Firebase của bạn (đã sửa lại storageBucket)
const firebaseConfig = {
  apiKey: "AIzaSyC4z9Q-lasHcw_gbsYvNod5N8pGkqs3BfE",
  authDomain: "minvestforexapp-33dff.firebaseapp.com",
  projectId: "minvestforexapp-33dff",
  storageBucket: "minvestforexapp-33dff.appspot.com", // SỬA LẠI THEO ĐỊNH DẠNG CHUẨN
  messagingSenderId: "245218403052",
  appId: "1:245218403052:web:30b6a6e919f731eeb03bc9",
  measurementId: "G-CRJG2SPE28"
};

// Khởi tạo Firebase
firebase.initializeApp(firebaseConfig);

// Lấy đối tượng Messaging. Chỉ cần có dòng này là đủ để
// service worker có thể nhận thông báo đẩy khi ứng dụng chạy nền.
const messaging = firebase.messaging();

console.log("Firebase Messaging Service Worker initialized.");