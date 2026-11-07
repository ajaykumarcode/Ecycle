const express = require("express");
const router = express.Router();

const {
  getDashboardStats,
  getAgents,
  createAgent,
  getAllPickups,
  assignPickup,
  getUsers,
  toggleUserStatus,
  getAnalytics,
} = require("../controllers/adminController");
const { protect, authorize } = require("../middleware/authMiddleware");

router.use(protect, authorize("admin"));

router.get("/stats", getDashboardStats);
router.get("/agents", getAgents);
router.post("/agents", createAgent);
router.get("/pickups", getAllPickups);
router.patch("/pickups/:id/assign", assignPickup);
router.get("/users", getUsers);
router.patch("/users/:id/toggle-status", toggleUserStatus);
router.get("/analytics", getAnalytics);

module.exports = router;
