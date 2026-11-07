const mongoose = require("mongoose");
const Pickup = require("../models/Pickup");

const categories = [
  "Mobile Phones",
  "Laptops & Computers",
  "Batteries",
  "Televisions & Monitors",
  "Home Appliances",
  "Other Electronics",
];

exports.createPickup = async (req, res) => {
  try {
    const {
      category,
      description,
      quantity,
      estimatedWeightKg,
      pickupAddress,
      scheduledDate,
      coordinates,
    } = req.body;

    if (!categories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: "Select a valid e-waste category.",
      });
    }

    if (
      !Number.isInteger(quantity) ||
      quantity < 1 ||
      quantity > 1000
    ) {
      return res.status(400).json({
        success: false,
        message: "Quantity must be a whole number between 1 and 1000.",
      });
    }

    if (
      typeof pickupAddress !== "string" ||
      pickupAddress.trim().length < 5 ||
      pickupAddress.trim().length > 300
    ) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid pickup address.",
      });
    }

    if (
      typeof scheduledDate !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(scheduledDate)
    ) {
      return res.status(400).json({
        success: false,
        message: "Select a valid pickup date.",
      });
    }

    const date = new Date(`${scheduledDate}T00:00:00.000Z`);
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    if (
      Number.isNaN(date.getTime()) ||
      date.toISOString().slice(0, 10) !== scheduledDate ||
      date < today
    ) {
      return res.status(400).json({
        success: false,
        message: "Pickup date cannot be in the past.",
      });
    }

    if (
      description !== undefined &&
      (typeof description !== "string" || description.length > 500)
    ) {
      return res.status(400).json({
        success: false,
        message: "Description must be 500 characters or fewer.",
      });
    }

    if (
      estimatedWeightKg !== undefined &&
      (
        typeof estimatedWeightKg !== "number" ||
        !Number.isFinite(estimatedWeightKg) ||
        estimatedWeightKg < 0 ||
        estimatedWeightKg > 100000
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid estimated weight.",
      });
    }

    let parsedCoords = null;
    if (
      coordinates &&
      typeof coordinates.lat === "number" &&
      typeof coordinates.lng === "number" &&
      Number.isFinite(coordinates.lat) &&
      Number.isFinite(coordinates.lng)
    ) {
      parsedCoords = {
        lat: coordinates.lat,
        lng: coordinates.lng,
      };
    }

    const pickup = await Pickup.create({
      user: req.user._id,
      category,
      description: description?.trim() ?? "",
      quantity,
      estimatedWeightKg: estimatedWeightKg ?? 0,
      pickupAddress: pickupAddress.trim(),
      scheduledDate: date,
      coordinates: parsedCoords,
    });

    return res.status(201).json({
      success: true,
      message: "Pickup request created successfully.",
      pickup,
    });
  } catch (error) {
    console.error("Create pickup error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to create pickup request.",
    });
  }
};

exports.getMyPickups = async (req, res) => {
  try {
    const filter = { user: req.user._id };

    if (req.query.status) {
      filter.status = req.query.status;
    }

    const pickups = await Pickup.find(filter)
      .populate("assignedAgent", "name phone email")
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return res.json({
      success: true,
      count: pickups.length,
      pickups,
    });
  } catch (error) {
    console.error("Get pickups error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve pickup requests.",
    });
  }
};

exports.getPickupById = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid pickup ID.",
      });
    }

    const pickup = await Pickup.findOne({
      _id: req.params.id,
      user: req.user._id,
    })
      .populate("assignedAgent", "name phone email")
      .lean();

    if (!pickup) {
      return res.status(404).json({
        success: false,
        message: "Pickup request not found.",
      });
    }

    return res.json({
      success: true,
      pickup,
    });
  } catch (error) {
    console.error("Get pickup by ID error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve pickup request.",
    });
  }
};

exports.cancelPickup = async (req, res) => {
  try {
    const pickup = await Pickup.findOne({
      _id: req.params.id,
      user: req.user._id,
    });

    if (!pickup) {
      return res.status(404).json({
        success: false,
        message: "Pickup request not found.",
      });
    }

    if (pickup.status !== "pending") {
      return res.status(409).json({
        success: false,
        message: "Only pending requests can be cancelled.",
      });
    }

    pickup.status = "cancelled";
    await pickup.save();

    return res.json({
      success: true,
      message: "Pickup request cancelled.",
      pickup,
    });
  } catch (error) {
    if (error.name === "CastError") {
      return res.status(400).json({
        success: false,
        message: "Invalid pickup ID.",
      });
    }

    console.error("Cancel pickup error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to cancel pickup request.",
    });
  }
};
