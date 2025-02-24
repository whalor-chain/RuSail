import { pgTable, text, serial, date, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull(),
  rusadaId: text("rusada_id"),
  worldSailingId: text("world_sailing_id"),
  certificates: text("certificates").array()
});

export const competitions = pgTable("competitions", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  location: text("location").notNull(),
  startDate: date("start_date").notNull(),
  endDate: date("end_date").notNull(),
  status: text("status").notNull(), // active, completed, upcoming
});

export const results = pgTable("results", {
  id: serial("id").primaryKey(),
  competitionId: serial("competition_id").notNull(),
  name: text("name").notNull(),
  date: date("date").notNull(),
  place: text("place").notNull()
});

export const insertUserSchema = createInsertSchema(users);
export const insertCompetitionSchema = createInsertSchema(competitions);
export const insertResultSchema = createInsertSchema(results);

export type User = typeof users.$inferSelect;
export type Competition = typeof competitions.$inferSelect;
export type Result = typeof results.$inferSelect;
export type InsertUser = z.infer<typeof insertUserSchema>;
export type InsertCompetition = z.infer<typeof insertCompetitionSchema>;
export type InsertResult = z.infer<typeof insertResultSchema>;
