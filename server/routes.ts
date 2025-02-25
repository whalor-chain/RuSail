import type { Express } from "express";
import { createServer } from "http";
import { storage } from "./storage";
import { setupAuth } from "./auth";

export async function registerRoutes(app: Express) {
  const httpServer = createServer(app);

  // Set up authentication routes and middleware
  setupAuth(app);

  // Active competitions
  app.get("/api/competitions/active", async (_req, res) => {
    const competitions = await storage.getActiveCompetitions();
    res.json(competitions);
  });

  // Competitions by year
  app.get("/api/competitions/:year", async (req, res) => {
    const year = parseInt(req.params.year);
    const competitions = await storage.getCompetitionsByYear(year);
    res.json(competitions);
  });

  // Results by competition
  app.get("/api/results/:competitionId", async (req, res) => {
    const competitionId = parseInt(req.params.competitionId);
    const results = await storage.getResults(competitionId);
    res.json(results);
  });

  // Protected routes
  app.use("/api/protected", (req, res, next) => {
    if (!req.isAuthenticated()) {
      return res.status(401).json({ message: "Unauthorized" });
    }
    next();
  });

  // Update user profile
  app.patch("/api/protected/user", async (req, res) => {
    const userId = req.user!.id;
    const updatedUser = await storage.updateUser(userId, req.body);
    res.json(updatedUser);
  });

  return httpServer;
}