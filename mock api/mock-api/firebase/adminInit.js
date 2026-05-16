"use strict";

const admin = require("firebase-admin");
const fs = require("fs");

// Prevent double-initialization (e.g., when required by multiple modules)
if (!admin.apps.length) {
  let credential;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    // Option 1: service account provided as a JSON string in the environment
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    } catch (err) {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_JSON is set but is not valid JSON: " + err.message
      );
    }
    credential = admin.credential.cert(serviceAccount);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    // Option 2: service account provided as a file path
    const filePath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    let serviceAccount;
    try {
      const raw = fs.readFileSync(filePath, "utf8");
      serviceAccount = JSON.parse(raw);
    } catch (err) {
      throw new Error(
        "Failed to read or parse service account file at FIREBASE_SERVICE_ACCOUNT_PATH (" +
          filePath +
          "): " +
          err.message
      );
    }
    credential = admin.credential.cert(serviceAccount);
  } else {
    throw new Error(
      "Firebase Admin SDK requires either FIREBASE_SERVICE_ACCOUNT_JSON or " +
        "FIREBASE_SERVICE_ACCOUNT_PATH to be set in the environment."
    );
  }

  admin.initializeApp({
    credential,
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
}

module.exports = admin;
