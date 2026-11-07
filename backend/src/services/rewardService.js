const RewardTransaction = require("../models/RewardTransaction");
const User = require("../models/User");

function calculatePoints(pickup) {
  const base = 10;
  const weight = typeof pickup.estimatedWeightKg === "number" ? pickup.estimatedWeightKg : 0;
  const quantity = typeof pickup.quantity === "number" ? pickup.quantity : 1;

  const points = Math.max(10, Math.round(base + weight * 5 + quantity * 2));
  return points;
}

async function awardPointsForPickup(pickup) {
  if (!pickup || !pickup.user) {
    return null;
  }

  const existingTx = await RewardTransaction.findOne({ pickup: pickup._id });
  if (existingTx) {
    return {
      awarded: false,
      reason: "already_awarded",
      transaction: existingTx,
    };
  }

  const points = calculatePoints(pickup);
  const description = `Earned ${points} points for recycling ${pickup.quantity} ${pickup.category} (${pickup.estimatedWeightKg || 0} kg)`;

  try {
    const transaction = await RewardTransaction.create({
      user: pickup.user,
      pickup: pickup._id,
      points,
      eventType: "pickup_recycled",
      description,
    });

    await User.findByIdAndUpdate(pickup.user, {
      $inc: { rewardPoints: points },
    });

    return {
      awarded: true,
      points,
      transaction,
    };
  } catch (error) {
    if (error.code === 11000) {
      const tx = await RewardTransaction.findOne({ pickup: pickup._id });
      return {
        awarded: false,
        reason: "already_awarded",
        transaction: tx,
      };
    }
    console.error("Failed to award points:", error.message);
    throw error;
  }
}

module.exports = {
  calculatePoints,
  awardPointsForPickup,
};
