const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
require("dotenv").config({ path: __dirname + "/../../.env" });

const User = require("../models/User");

async function seedAdmin() {
  try {
    const uri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/ecycle";
    await mongoose.connect(uri);

    const existingAdmin = await User.findOne({ role: "admin" });

    if (existingAdmin) {
      console.log(`Admin account already exists: ${existingAdmin.email}`);
      process.exit(0);
    }

    const hashedPassword = await bcrypt.hash("Admin@ecycle123", 12);

    const admin = await User.create({
      name: "System Administrator",
      email: "admin@ecycle.com",
      password: hashedPassword,
      phone: "+1-800-ECYCLE",
      role: "admin",
      isActive: true,
      rewardPoints: 0,
    });

    console.log(`Default admin account created successfully: ${admin.email}`);
    process.exit(0);
  } catch (error) {
    console.error("Failed to seed admin:", error);
    process.exit(1);
  }
}

seedAdmin();
