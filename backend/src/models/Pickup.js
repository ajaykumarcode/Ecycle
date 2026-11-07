const mongoose = require("mongoose");

const pickupSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    category: {
      type: String,
      enum: [
        "Mobile Phones",
        "Laptops & Computers",
        "Batteries",
        "Televisions & Monitors",
        "Home Appliances",
        "Other Electronics",
      ],
      required: true,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 500,
      default: "",
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
      max: 1000,
    },
    estimatedWeightKg: {
      type: Number,
      min: 0,
      default: 0,
    },
    pickupAddress: {
      type: String,
      required: true,
      trim: true,
      maxlength: 300,
    },
    coordinates: {
      lat: {
        type: Number,
        default: null,
      },
      lng: {
        type: Number,
        default: null,
      },
    },
    scheduledDate: {
      type: Date,
      required: true,
    },
    status: {
      type: String,
      enum: [
        "pending",
        "assigned",
        "collected",
        "recycled",
        "cancelled",
      ],
      default: "pending",
      index: true,
    },
    assignedAgent: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
      index: true,
    },
    assignedAt: {
      type: Date,
      default: null,
    },
    collectedAt: {
      type: Date,
      default: null,
    },
    recycledAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Pickup", pickupSchema);
