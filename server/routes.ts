import type { Express } from "express";
import { createServer } from "http";
import { storage } from "./storage";

export async function registerRoutes(app: Express) {
  const httpServer = createServer(app);

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

  // User profile
  app.get("/api/users/:id", async (req, res) => {
    const id = parseInt(req.params.id);
    const user = await storage.getUser(id);
    if (!user) {
      res.status(404).json({ message: "User not found" });
      return;
    }
    res.json(user);
  });

  return httpServer;
}
