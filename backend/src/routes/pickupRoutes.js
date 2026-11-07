const express = require("express");
const router = express.Router();

const {
  createPickup,
  getMyPickups,
  getPickupById,
  cancelPickup,
} = require("../controllers/pickupController");

const { protect, authorize } = require("../middleware/authMiddleware");

router.use(protect, authorize("user"));

router.post("/", createPickup);
router.get("/my", getMyPickups);
router.get("/:id", getPickupById);
router.patch("/:id/cancel", cancelPickup);

module.exports = router;
