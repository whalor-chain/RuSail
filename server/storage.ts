import { Competition, InsertCompetition, User, InsertUser, Result, InsertResult } from "@shared/schema";
import session from "express-session";
import createMemoryStore from "memorystore";

const MemoryStore = createMemoryStore(session);

export interface IStorage {
  // Users
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  updateUser(id: number, user: Partial<User>): Promise<User>;

  // Competitions
  getActiveCompetitions(): Promise<Competition[]>;
  getCompetitionsByYear(year: number): Promise<Competition[]>;
  createCompetition(competition: InsertCompetition): Promise<Competition>;

  // Results
  getResults(competitionId: number): Promise<Result[]>;
  createResult(result: InsertResult): Promise<Result>;

  // Session store
  sessionStore: session.Store;
}

export class MemStorage implements IStorage {
  private users: Map<number, User>;
  private usersByUsername: Map<string, User>;
  private competitions: Map<number, Competition>;
  private results: Map<number, Result>;
  private currentIds: { [key: string]: number };
  readonly sessionStore: session.Store;

  constructor() {
    this.users = new Map();
    this.usersByUsername = new Map();
    this.competitions = new Map();
    this.results = new Map();
    this.currentIds = { users: 1, competitions: 1, results: 1 };
    this.sessionStore = new MemoryStore({
      checkPeriod: 86400000, // Очистка устаревших сессий каждые 24 часа
    });

    // Add sample data
    this.initSampleData();
  }

  private initSampleData() {
    const sampleCompetition: InsertCompetition = {
      name: "Кубок Сибири и Дальнего востока",
      location: "Владивосток",
      startDate: new Date("2024-02-15"),
      endDate: new Date("2024-02-21"),
      status: "active"
    };
    this.createCompetition(sampleCompetition);
  }

  async getUser(id: number): Promise<User | undefined> {
    return this.users.get(id);
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    return this.usersByUsername.get(username);
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const id = this.currentIds.users++;
    const user = { ...insertUser, id };
    this.users.set(id, user);
    this.usersByUsername.set(user.username, user);
    return user;
  }

  async updateUser(id: number, data: Partial<User>): Promise<User> {
    const user = await this.getUser(id);
    if (!user) {
      throw new Error("User not found");
    }

    const updatedUser = { ...user, ...data };
    this.users.set(id, updatedUser);
    this.usersByUsername.set(updatedUser.username, updatedUser);
    return updatedUser;
  }

  async getActiveCompetitions(): Promise<Competition[]> {
    return Array.from(this.competitions.values())
      .filter(comp => comp.status === "active");
  }

  async getCompetitionsByYear(year: number): Promise<Competition[]> {
    return Array.from(this.competitions.values())
      .filter(comp => new Date(comp.startDate).getFullYear() === year);
  }

  async createCompetition(insertCompetition: InsertCompetition): Promise<Competition> {
    const id = this.currentIds.competitions++;
    const competition = { ...insertCompetition, id };
    this.competitions.set(id, competition);
    return competition;
  }

  async getResults(competitionId: number): Promise<Result[]> {
    return Array.from(this.results.values())
      .filter(result => result.competitionId === competitionId);
  }

  async createResult(insertResult: InsertResult): Promise<Result> {
    const id = this.currentIds.results++;
    const result = { ...insertResult, id };
    this.results.set(id, result);
    return result;
  }
}

export const storage = new MemStorage();