// middleware/firebaseAuth.js
const admin = require("../firebase/adminInit");

async function firebaseAuth(req, res, next) {
  const authHeader = req.headers["authorization"] || "";
  if (!authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or malformed Authorization header" });
  }

  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.firebaseUid = decoded.uid;
    req.cartUserId = "user_001";
    next();
  } catch (err) {
    return res.status(401).json({ error: "Invalid or expired Firebase token" });
  }
}

module.exports = firebaseAuth;
