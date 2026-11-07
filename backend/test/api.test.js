const { describe, it, before, after } = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const mongoose = require("mongoose");
require("dotenv").config({ path: __dirname + "/../.env" });

const app = require("../src/server");
const User = require("../src/models/User");
const Pickup = require("../src/models/Pickup");
const RewardTransaction = require("../src/models/RewardTransaction");

let server;
let baseUrl;

function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const headers = { "Content-Type": "application/json" };
    if (token) headers["Authorization"] = `Bearer ${token}`;

    const req = http.request(
      url,
      { method, headers },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          let json = {};
          try {
            json = JSON.parse(data);
          } catch (_) {
            json = { raw: data };
          }
          resolve({ status: res.statusCode, body: json });
        });
      }
    );

    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

describe("E-Cycle Backend Full-Stack API Suite", () => {
  let userToken;
  let userId;
  let agentToken;
  let agentId;
  let adminToken;
  let pickupId;

  const testUserEmail = `testuser_${Date.now()}@example.com`;
  const testAgentEmail = `testagent_${Date.now()}@example.com`;

  before(async () => {
    const uri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/ecycle";
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(uri);
    }

    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}`;
  });

  after(async () => {
    // Cleanup created test records
    if (userId) await User.deleteOne({ _id: userId });
    if (agentId) await User.deleteOne({ _id: agentId });
    if (pickupId) {
      await Pickup.deleteOne({ _id: pickupId });
      await RewardTransaction.deleteOne({ pickup: pickupId });
    }

    await new Promise((resolve) => server.close(resolve));
    await mongoose.disconnect();
  });

  it("1. Health check returns 200 and connected database", async () => {
    const res = await request("GET", "/api/health");
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.database, "connected");
  });

  it("2. User registration enforces role 'user'", async () => {
    const res = await request("POST", "/api/auth/register", {
      name: "Test Green Citizen",
      email: testUserEmail,
      password: "Password123!",
      phone: "+1234567890",
      role: "admin", // attempt privilege escalation
    });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.user.role, "user"); // Escalation blocked!
    assert.ok(res.body.token);

    userToken = res.body.token;
    userId = res.body.user.id;
  });

  it("3. User cannot access admin or agent endpoints", async () => {
    const adminRes = await request("GET", "/api/admin/pickups", null, userToken);
    assert.strictEqual(adminRes.status, 403);

    const agentRes = await request("GET", "/api/agent/pickups", null, userToken);
    assert.strictEqual(agentRes.status, 403);
  });

  it("4. Admin logs in with seeded admin account", async () => {
    const res = await request("POST", "/api/auth/login", {
      email: "admin@ecycle.com",
      password: "Admin@ecycle123",
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.user.role, "admin");
    adminToken = res.body.token;
  });

  it("5. Admin creates an active collection agent", async () => {
    const res = await request(
      "POST",
      "/api/admin/agents",
      {
        name: "Eco Collector Bob",
        email: testAgentEmail,
        password: "AgentPassword123!",
        phone: "+9876543210",
      },
      adminToken
    );

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.agent.role, "agent");
    agentId = res.body.agent.id;

    // Login as the agent
    const loginRes = await request("POST", "/api/auth/login", {
      email: testAgentEmail,
      password: "AgentPassword123!",
    });
    assert.strictEqual(loginRes.status, 200);
    agentToken = loginRes.body.token;
  });

  it("6. Normal user creates a pickup request", async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dateStr = tomorrow.toISOString().slice(0, 10);

    const res = await request(
      "POST",
      "/api/pickups",
      {
        category: "Laptops & Computers",
        description: "2 old Dell laptops with chargers",
        quantity: 2,
        estimatedWeightKg: 4.5,
        pickupAddress: "42 Greenfield Avenue, Eco District",
        scheduledDate: dateStr,
        coordinates: { lat: 12.9716, lng: 77.5946 },
      },
      userToken
    );

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.pickup.status, "pending");
    pickupId = res.body.pickup._id;
  });

  it("7. User can retrieve their created pickup", async () => {
    const res = await request("GET", "/api/pickups/my", null, userToken);
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.pickups.some((p) => p._id === pickupId));
  });

  it("8. Admin views all pickups and assigns pickup to agent", async () => {
    const allRes = await request("GET", "/api/admin/pickups", null, adminToken);
    assert.strictEqual(allRes.status, 200);
    assert.ok(allRes.body.pickups.some((p) => p._id === pickupId));

    const assignRes = await request(
      "PATCH",
      `/api/admin/pickups/${pickupId}/assign`,
      { agentId },
      adminToken
    );

    assert.strictEqual(assignRes.status, 200);
    assert.strictEqual(assignRes.body.pickup.status, "assigned");
    assert.strictEqual(assignRes.body.pickup.assignedAgent._id.toString(), agentId.toString());
  });

  it("9. Agent views assigned pickup in their dashboard", async () => {
    const res = await request("GET", "/api/agent/pickups", null, agentToken);
    assert.strictEqual(res.status, 200);
    const assigned = res.body.pickups.find((p) => p._id === pickupId);
    assert.ok(assigned);
    assert.strictEqual(assigned.status, "assigned");
    assert.strictEqual(assigned.user.name, "Test Green Citizen");
  });

  it("10. Agent marks pickup as collected", async () => {
    const res = await request(
      "PATCH",
      `/api/agent/pickups/${pickupId}/status`,
      { status: "collected" },
      agentToken
    );

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.pickup.status, "collected");
    assert.ok(res.body.pickup.collectedAt);
  });

  it("11. Agent marks pickup as recycled -> triggers rewards", async () => {
    const res = await request(
      "PATCH",
      `/api/agent/pickups/${pickupId}/status`,
      { status: "recycled" },
      agentToken
    );

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.pickup.status, "recycled");
    assert.ok(res.body.pickup.recycledAt);
    assert.ok(res.body.rewardResult);
    assert.strictEqual(res.body.rewardResult.awarded, true);
    assert.ok(res.body.rewardResult.points >= 10);
  });

  it("12. User profile reflects awarded reward points and transaction history", async () => {
    const rewardsRes = await request("GET", "/api/auth/rewards", null, userToken);
    assert.strictEqual(rewardsRes.status, 200);
    assert.ok(rewardsRes.body.totalPoints >= 10);
    assert.strictEqual(rewardsRes.body.history.length, 1);
    assert.strictEqual(rewardsRes.body.history[0].pickup._id, pickupId);
  });

  it("13. Admin stats and analytics reflect completed recycling", async () => {
    const statsRes = await request("GET", "/api/admin/stats", null, adminToken);
    assert.strictEqual(statsRes.status, 200);
    assert.ok(statsRes.body.stats.recycledPickups >= 1);
    assert.ok(statsRes.body.stats.totalRecycledWeightKg > 0);

    const analyticsRes = await request("GET", "/api/admin/analytics", null, adminToken);
    assert.strictEqual(analyticsRes.status, 200);
    assert.ok(Array.isArray(analyticsRes.body.analytics.categoryDistribution));
    assert.ok(Array.isArray(analyticsRes.body.analytics.agentPerformance));
  });
});
