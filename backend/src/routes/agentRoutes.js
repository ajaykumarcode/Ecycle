const express = require("express");
const router = express.Router();

const {
  getAssignedPickups,
  updatePickupStatus,
} = require("../controllers/agentController");
const { protect, authorize } = require("../middleware/authMiddleware");

router.use(protect, authorize("agent"));
router.get("/pickups", getAssignedPickups);
router.patch("/pickups/:id/status", updatePickupStatus);

module.exports = router;
