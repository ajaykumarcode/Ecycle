const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const Pickup = require("../models/Pickup");
const User = require("../models/User");

exports.getDashboardStats = async (req, res) => {
  try {
    const [
      totalUsers,
      totalAgents,
      pickupCounts,
      weightAgg,
      recentPickups,
    ] = await Promise.all([
      User.countDocuments({ role: "user" }),
      User.countDocuments({ role: "agent" }),
      Pickup.aggregate([
        {
          $group: {
            _id: "$status",
            count: { $sum: 1 },
          },
        },
      ]),
      Pickup.aggregate([
        {
          $group: {
            _id: null,
            totalWeight: { $sum: "$estimatedWeightKg" },
            recycledWeight: {
              $sum: {
                $cond: [
                  { $eq: ["$status", "recycled"] },
                  "$estimatedWeightKg",
                  0,
                ],
              },
            },
          },
        },
      ]),
      Pickup.find()
        .populate("user", "name email phone")
        .populate("assignedAgent", "name email phone")
        .sort({ createdAt: -1 })
        .limit(5)
        .lean(),
    ]);

    const statusMap = {
      pending: 0,
      assigned: 0,
      collected: 0,
      recycled: 0,
      cancelled: 0,
    };

    let totalPickups = 0;
    pickupCounts.forEach((item) => {
      if (statusMap[item._id] !== undefined) {
        statusMap[item._id] = item.count;
      }
      totalPickups += item.count;
    });

    const totalWeight = weightAgg[0]?.totalWeight || 0;
    const recycledWeight = weightAgg[0]?.recycledWeight || 0;

    return res.json({
      success: true,
      stats: {
        totalUsers,
        totalAgents,
        totalPickups,
        pendingPickups: statusMap.pending,
        assignedPickups: statusMap.assigned,
        collectedPickups: statusMap.collected,
        recycledPickups: statusMap.recycled,
        cancelledPickups: statusMap.cancelled,
        totalEstimatedWeightKg: Math.round(totalWeight * 10) / 10,
        totalRecycledWeightKg: Math.round(recycledWeight * 10) / 10,
      },
      recentPickups,
    });
  } catch (error) {
    console.error("Get dashboard stats error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to load dashboard stats.",
    });
  }
};

exports.getAgents = async (req, res) => {
  try {
    const filter = { role: "agent" };
    if (req.query.activeOnly !== "false") {
      filter.isActive = true;
    }

    const agents = await User.find(filter)
      .select("name email phone isActive createdAt")
      .sort({ name: 1 })
      .lean();

    const agentIds = agents.map((a) => a._id);
    const workloads = await Pickup.aggregate([
      { $match: { assignedAgent: { $in: agentIds } } },
      {
        $group: {
          _id: { agent: "$assignedAgent", status: "$status" },
          count: { $sum: 1 },
        },
      },
    ]);

    const workloadMap = {};
    workloads.forEach((w) => {
      const agentId = w._id.agent.toString();
      if (!workloadMap[agentId]) {
        workloadMap[agentId] = { assigned: 0, collected: 0, recycled: 0 };
      }
      if (workloadMap[agentId][w._id.status] !== undefined) {
        workloadMap[agentId][w._id.status] = w.count;
      }
    });

    const enrichedAgents = agents.map((agent) => ({
      ...agent,
      workload: workloadMap[agent._id.toString()] || {
        assigned: 0,
        collected: 0,
        recycled: 0,
      },
    }));

    return res.json({
      success: true,
      count: enrichedAgents.length,
      agents: enrichedAgents,
    });
  } catch (error) {
    console.error("Get agents error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve agents.",
    });
  }
};

exports.createAgent = async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;

    if (
      typeof name !== "string" ||
      typeof email !== "string" ||
      typeof password !== "string" ||
      name.trim().length < 2 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) ||
      password.length < 8
    ) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid name, email, and password of at least 8 characters.",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const existingUser = await User.findOne({ email: normalizedEmail });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: "An account with this email already exists.",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const agent = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      password: hashedPassword,
      phone: typeof phone === "string" ? phone.trim() : "",
      role: "agent",
      isActive: true,
    });

    return res.status(201).json({
      success: true,
      message: "Collection agent created successfully.",
      agent: {
        id: agent._id,
        name: agent.name,
        email: agent.email,
        phone: agent.phone,
        role: agent.role,
        isActive: agent.isActive,
      },
    });
  } catch (error) {
    console.error("Create agent error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to create collection agent.",
    });
  }
};

exports.getAllPickups = async (req, res) => {
  try {
    const filter = {};
    const allowedStatuses = [
      "pending",
      "assigned",
      "collected",
      "recycled",
      "cancelled",
    ];

    if (req.query.status) {
      if (!allowedStatuses.includes(req.query.status)) {
        return res.status(400).json({
          success: false,
          message: "Invalid pickup status filter.",
        });
      }
      filter.status = req.query.status;
    }

    if (req.query.category) {
      filter.category = req.query.category;
    }

    if (req.query.startDate || req.query.endDate) {
      filter.scheduledDate = {};
      if (req.query.startDate) {
        filter.scheduledDate.$gte = new Date(req.query.startDate);
      }
      if (req.query.endDate) {
        const end = new Date(req.query.endDate);
        end.setUTCHours(23, 59, 59, 999);
        filter.scheduledDate.$lte = end;
      }
    }

    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search.trim(), "i");
      filter.$or = [
        { pickupAddress: searchRegex },
        { description: searchRegex },
        { category: searchRegex },
      ];
    }

    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(500, Math.max(1, parseInt(req.query.limit, 10) || 100));
    const skip = (page - 1) * limit;

    const [total, pickups] = await Promise.all([
      Pickup.countDocuments(filter),
      Pickup.find(filter)
        .populate("user", "name email phone")
        .populate("assignedAgent", "name email phone")
        .sort({ scheduledDate: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
    ]);

    return res.json({
      success: true,
      count: pickups.length,
      total,
      page,
      totalPages: Math.ceil(total / limit),
      pickups,
    });
  } catch (error) {
    console.error("Get all pickups error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve pickup requests.",
    });
  }
};

exports.assignPickup = async (req, res) => {
  try {
    const { agentId } = req.body;

    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid pickup ID.",
      });
    }

    if (!mongoose.isValidObjectId(agentId)) {
      return res.status(400).json({
        success: false,
        message: "Select a valid collection agent.",
      });
    }

    const agent = await User.findOne({
      _id: agentId,
      role: "agent",
      isActive: true,
    }).select("_id name email phone");

    if (!agent) {
      return res.status(404).json({
        success: false,
        message: "Active collection agent not found.",
      });
    }

    const pickup = await Pickup.findById(req.params.id);

    if (!pickup) {
      return res.status(404).json({
        success: false,
        message: "Pickup request not found.",
      });
    }

    if (pickup.status !== "pending" || pickup.assignedAgent) {
      return res.status(409).json({
        success: false,
        message: "Only unassigned pending pickups can be assigned.",
      });
    }

    pickup.assignedAgent = agent._id;
    pickup.status = "assigned";
    pickup.assignedAt = new Date();
    await pickup.save();

    await pickup.populate([
      { path: "user", select: "name email phone" },
      { path: "assignedAgent", select: "name email phone" },
    ]);

    return res.json({
      success: true,
      message: `Pickup assigned to ${agent.name}.`,
      pickup,
    });
  } catch (error) {
    console.error("Assign pickup error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to assign pickup.",
    });
  }
};

exports.getUsers = async (req, res) => {
  try {
    const filter = { role: "user" };

    if (req.query.search) {
      const regex = new RegExp(req.query.search.trim(), "i");
      filter.$or = [{ name: regex }, { email: regex }, { phone: regex }];
    }

    const users = await User.find(filter)
      .select("name email phone rewardPoints isActive createdAt")
      .sort({ createdAt: -1 })
      .lean();

    const userIds = users.map((u) => u._id);
    const pickupCounts = await Pickup.aggregate([
      { $match: { user: { $in: userIds } } },
      { $group: { _id: "$user", totalPickups: { $sum: 1 } } },
    ]);

    const countMap = {};
    pickupCounts.forEach((pc) => {
      countMap[pc._id.toString()] = pc.totalPickups;
    });

    const enrichedUsers = users.map((u) => ({
      ...u,
      pickupCount: countMap[u._id.toString()] || 0,
    }));

    return res.json({
      success: true,
      count: enrichedUsers.length,
      users: enrichedUsers,
    });
  } catch (error) {
    console.error("Get users error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve users.",
    });
  }
};

exports.toggleUserStatus = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid account ID.",
      });
    }

    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    if (user.role === "admin") {
      return res.status(403).json({
        success: false,
        message: "Cannot modify administrator status.",
      });
    }

    user.isActive = !user.isActive;
    await user.save();

    return res.json({
      success: true,
      message: `Account has been ${user.isActive ? "activated" : "deactivated"}.`,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        isActive: user.isActive,
      },
    });
  } catch (error) {
    console.error("Toggle user status error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to change account status.",
    });
  }
};

exports.getAnalytics = async (req, res) => {
  try {
    const [
      categoryDistribution,
      monthlyTrends,
      agentPerformance,
      statusBreakdown,
    ] = await Promise.all([
      Pickup.aggregate([
        {
          $group: {
            _id: "$category",
            count: { $sum: 1 },
            weight: { $sum: "$estimatedWeightKg" },
          },
        },
        { $sort: { count: -1 } },
      ]),
      Pickup.aggregate([
        {
          $group: {
            _id: {
              year: { $year: "$createdAt" },
              month: { $month: "$createdAt" },
            },
            count: { $sum: 1 },
            weight: { $sum: "$estimatedWeightKg" },
            recycledCount: {
              $sum: {
                $cond: [{ $eq: ["$status", "recycled"] }, 1, 0],
              },
            },
          },
        },
        { $sort: { "_id.year": 1, "_id.month": 1 } },
      ]),
      Pickup.aggregate([
        { $match: { assignedAgent: { $ne: null } } },
        {
          $group: {
            _id: "$assignedAgent",
            assignedCount: { $sum: 1 },
            collectedCount: {
              $sum: {
                $cond: [
                  { $in: ["$status", ["collected", "recycled"]] },
                  1,
                  0,
                ],
              },
            },
            recycledCount: {
              $sum: {
                $cond: [{ $eq: ["$status", "recycled"] }, 1, 0],
              },
            },
          },
        },
        {
          $lookup: {
            from: "users",
            localField: "_id",
            foreignField: "_id",
            as: "agent",
          },
        },
        { $unwind: "$agent" },
        {
          $project: {
            _id: 1,
            name: "$agent.name",
            email: "$agent.email",
            assignedCount: 1,
            collectedCount: 1,
            recycledCount: 1,
          },
        },
        { $sort: { recycledCount: -1 } },
      ]),
      Pickup.aggregate([
        {
          $group: {
            _id: "$status",
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    return res.json({
      success: true,
      analytics: {
        categoryDistribution,
        monthlyTrends,
        agentPerformance,
        statusBreakdown,
      },
    });
  } catch (error) {
    console.error("Get analytics error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Unable to retrieve analytics.",
    });
  }
};
