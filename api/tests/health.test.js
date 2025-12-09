import request from "supertest";
import app from "../app.js";

describe("GET /health", () => {
  test("respond with 200 and OK", async () => {
    const res = await request(app).get("/health");

    expect(res.statusCode).toBe(200);
    expect(res.text).toBe("OK");
  });
});
