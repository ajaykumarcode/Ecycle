const mongoose = require("mongoose");

const rewardTransactionSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    pickup: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Pickup",
      required: true,
      unique: true,
    },
    points: {
      type: Number,
      required: true,
      min: 1,
    },
    eventType: {
      type: String,
      default: "pickup_recycled",
    },
    description: {
      type: String,
      default: "",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("RewardTransaction", rewardTransactionSchema);
