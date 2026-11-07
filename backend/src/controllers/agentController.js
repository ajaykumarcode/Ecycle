const mongoose = require("mongoose");
const Pickup = require("../models/Pickup");
const rewardService = require("../services/rewardService");

exports.getAssignedPickups = async (req, res) => {
  try {
    const pickups = await Pickup.find({ assignedAgent: req.user._id })
      .populate("user", "name phone email")
      .sort({ scheduledDate: 1, createdAt: -1 })
      .limit(200)
      .lean();

    return res.json({
      success: true,
      count: pickups.length,
      pickups,
    });
  } catch (error) {
    console.error("Get assigned pickups error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve assigned pickups.",
    });
  }
};

exports.updatePickupStatus = async (req, res) => {
  try {
    const { status } = req.body;

    if (!["collected", "recycled"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Status must be collected or recycled.",
      });
    }

    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid pickup ID.",
      });
    }

    const pickup = await Pickup.findOne({
      _id: req.params.id,
      assignedAgent: req.user._id,
    });

    if (!pickup) {
      return res.status(404).json({
        success: false,
        message: "Assigned pickup not found.",
      });
    }

    const allowedNextStatus = {
      assigned: "collected",
      collected: "recycled",
    };

    if (allowedNextStatus[pickup.status] !== status) {
      return res.status(409).json({
        success: false,
        message:
          pickup.status === "assigned"
            ? "Mark this pickup as collected before marking it recycled."
            : "This pickup cannot be moved to that status.",
      });
    }

    pickup.status = status;
    if (status === "collected") {
      pickup.collectedAt = new Date();
    } else if (status === "recycled") {
      pickup.recycledAt = new Date();
    }

    await pickup.save();

    let rewardResult = null;
    if (status === "recycled") {
      rewardResult = await rewardService.awardPointsForPickup(pickup);
    }

    await pickup.populate([
      { path: "user", select: "name phone email rewardPoints" },
      { path: "assignedAgent", select: "name phone email" },
    ]);

    return res.json({
      success: true,
      message: `Pickup status updated to ${status}.`,
      pickup,
      rewardResult,
    });
  } catch (error) {
    if (error instanceof mongoose.Error.CastError) {
      return res.status(400).json({
        success: false,
        message: "Invalid pickup ID.",
      });
    }

    console.error("Update pickup status error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to update pickup status.",
    });
  }
};
