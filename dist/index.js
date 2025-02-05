// src/index.ts
import { createClient } from "@supabase/supabase-js";
import {
  elizaLogger
} from "@elizaos/core";
import { DatabaseAdapter } from "@elizaos/core";
import { v4 as uuid } from "uuid";
var SupabaseDatabaseAdapter = class extends DatabaseAdapter {
  async getRoom(roomId) {
    const { data, error } = await this.supabase.from("rooms").select("id").eq("id", roomId).maybeSingle();
    if (error) {
      elizaLogger.error(`Error getting room: ${error.message}`);
      return null;
    }
    return data ? data.id : null;
  }
  async getParticipantsForAccount(userId) {
    const { data, error } = await this.supabase.from("participants").select("*").eq("userId", userId);
    if (error) {
      throw new Error(
        `Error getting participants for account: ${error.message}`
      );
    }
    return data;
  }
  async getParticipantUserState(roomId, userId) {
    const { data, error } = await this.supabase.from("participants").select("userState").eq("roomId", roomId).eq("userId", userId).single();
    if (error) {
      elizaLogger.error("Error getting participant user state:", error);
      return null;
    }
    return data?.userState;
  }
  async setParticipantUserState(roomId, userId, state) {
    const { error } = await this.supabase.from("participants").update({ userState: state }).eq("roomId", roomId).eq("userId", userId);
    if (error) {
      elizaLogger.error("Error setting participant user state:", error);
      throw new Error("Failed to set participant user state");
    }
  }
  async getParticipantsForRoom(roomId) {
    const { data, error } = await this.supabase.from("participants").select("userId").eq("roomId", roomId);
    if (error) {
      throw new Error(
        `Error getting participants for room: ${error.message}`
      );
    }
    return data.map((row) => row.userId);
  }
  supabase;
  constructor(supabaseUrl, supabaseKey) {
    super();
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }
  async init() {
  }
  async close() {
  }
  async getMemoriesByRoomIds(params) {
    let query = this.supabase.from(params.tableName).select("*").in("roomId", params.roomIds).order("createdAt", { ascending: false });
    if (params.agentId) {
      query = query.eq("agentId", params.agentId);
    }
    if (params.limit) {
      query = query.limit(params.limit);
    }
    const { data, error } = await query;
    if (error) {
      elizaLogger.error("Error retrieving memories by room IDs:", error);
      return [];
    }
    const memories = data.map((memory) => ({
      ...memory
    }));
    return memories;
  }
  async getAccountById(userId) {
    const { data, error } = await this.supabase.from("accounts").select("*").eq("id", userId);
    if (error) {
      throw new Error(error.message);
    }
    return data?.[0] || null;
  }
  async createAccount(account) {
    const { error } = await this.supabase.from("accounts").upsert([account]);
    if (error) {
      elizaLogger.error(error.message);
      return false;
    }
    return true;
  }
  async getActorDetails(params) {
    try {
      const response = await this.supabase.from("rooms").select(
        `
          participants:participants(
            account:accounts(id, name, username, details)
          )
      `
      ).eq("id", params.roomId);
      if (response.error) {
        elizaLogger.error("Error!" + response.error);
        return [];
      }
      const { data } = response;
      return data.flatMap(
        (room) => room.participants.map((participant) => {
          const user = participant.account;
          return {
            name: user?.name,
            details: user?.details,
            id: user?.id,
            username: user?.username
          };
        })
      );
    } catch (error) {
      elizaLogger.error("error", error);
      throw error;
    }
  }
  async searchMemories(params) {
    const result = await this.supabase.rpc("search_memories", {
      query_table_name: params.tableName,
      query_roomId: params.roomId,
      query_embedding: params.embedding,
      query_match_threshold: params.match_threshold,
      query_match_count: params.match_count,
      query_unique: params.unique
    });
    if (result.error) {
      throw new Error(JSON.stringify(result.error));
    }
    return result.data.map((memory) => ({
      ...memory
    }));
  }
  async getCachedEmbeddings(opts) {
    const result = await this.supabase.rpc("get_embedding_list", opts);
    if (result.error) {
      throw new Error(JSON.stringify(result.error));
    }
    return result.data;
  }
  async updateGoalStatus(params) {
    await this.supabase.from("goals").update({ status: params.status }).match({ id: params.goalId });
  }
  async log(params) {
    const { error } = await this.supabase.from("logs").insert({
      body: params.body,
      userId: params.userId,
      roomId: params.roomId,
      type: params.type
    });
    if (error) {
      elizaLogger.error("Error inserting log:", error);
      throw new Error(error.message);
    }
  }
  async getMemories(params) {
    const query = this.supabase.from(params.tableName).select("*").eq("roomId", params.roomId);
    if (params.start) {
      query.gte("createdAt", params.start);
    }
    if (params.end) {
      query.lte("createdAt", params.end);
    }
    if (params.unique) {
      query.eq("unique", true);
    }
    if (params.agentId) {
      query.eq("agentId", params.agentId);
    }
    query.order("createdAt", { ascending: false });
    if (params.count) {
      query.limit(params.count);
    }
    const { data, error } = await query;
    if (error) {
      throw new Error(`Error retrieving memories: ${error.message}`);
    }
    return data;
  }
  async searchMemoriesByEmbedding(embedding, params) {
    const queryParams = {
      query_table_name: params.tableName,
      query_roomId: params.roomId,
      query_embedding: embedding,
      query_match_threshold: params.match_threshold,
      query_match_count: params.count,
      query_unique: !!params.unique
    };
    if (params.agentId) {
      queryParams.query_agentId = params.agentId;
    }
    const result = await this.supabase.rpc("search_memories", queryParams);
    if (result.error) {
      throw new Error(JSON.stringify(result.error));
    }
    return result.data.map((memory) => ({
      ...memory
    }));
  }
  async getMemoryById(memoryId) {
    const { data, error } = await this.supabase.from("memories").select("*").eq("id", memoryId).single();
    if (error) {
      elizaLogger.error("Error retrieving memory by ID:", error);
      return null;
    }
    return data;
  }
  async getMemoriesByIds(memoryIds, tableName) {
    if (memoryIds.length === 0) return [];
    let query = this.supabase.from("memories").select("*").in("id", memoryIds);
    if (tableName) {
      query = query.eq("type", tableName);
    }
    const { data, error } = await query;
    if (error) {
      console.error("Error retrieving memories by IDs:", error);
      return [];
    }
    return data;
  }
  async createMemory(memory, tableName, unique = false) {
    const createdAt = memory.createdAt ?? Date.now();
    if (unique) {
      const opts = {
        // TODO: Add ID option, optionally
        query_table_name: tableName,
        query_userId: memory.userId,
        query_content: memory.content.text,
        query_roomId: memory.roomId,
        query_embedding: memory.embedding,
        query_createdAt: createdAt,
        similarity_threshold: 0.95
      };
      const result = await this.supabase.rpc(
        "check_similarity_and_insert",
        opts
      );
      if (result.error) {
        throw new Error(JSON.stringify(result.error));
      }
    } else {
      const result = await this.supabase.from("memories").insert({ ...memory, createdAt, type: tableName });
      const { error } = result;
      if (error) {
        throw new Error(JSON.stringify(error));
      }
    }
  }
  async removeMemory(memoryId) {
    const result = await this.supabase.from("memories").delete().eq("id", memoryId);
    const { error } = result;
    if (error) {
      throw new Error(JSON.stringify(error));
    }
  }
  async removeAllMemories(roomId, tableName) {
    const result = await this.supabase.rpc("remove_memories", {
      query_table_name: tableName,
      query_roomId: roomId
    });
    if (result.error) {
      throw new Error(JSON.stringify(result.error));
    }
  }
  async countMemories(roomId, unique = true, tableName) {
    if (!tableName) {
      throw new Error("tableName is required");
    }
    const query = {
      query_table_name: tableName,
      query_roomId: roomId,
      query_unique: !!unique
    };
    const result = await this.supabase.rpc("count_memories", query);
    if (result.error) {
      throw new Error(JSON.stringify(result.error));
    }
    return result.data;
  }
  async getGoals(params) {
    const opts = {
      query_roomId: params.roomId,
      query_userId: params.userId,
      only_in_progress: params.onlyInProgress,
      row_count: params.count
    };
    const { data: goals, error } = await this.supabase.rpc(
      "get_goals",
      opts
    );
    if (error) {
      throw new Error(error.message);
    }
    return goals;
  }
  async updateGoal(goal) {
    const { error } = await this.supabase.from("goals").update(goal).match({ id: goal.id });
    if (error) {
      throw new Error(`Error creating goal: ${error.message}`);
    }
  }
  async createGoal(goal) {
    const { error } = await this.supabase.from("goals").insert(goal);
    if (error) {
      throw new Error(`Error creating goal: ${error.message}`);
    }
  }
  async removeGoal(goalId) {
    const { error } = await this.supabase.from("goals").delete().eq("id", goalId);
    if (error) {
      throw new Error(`Error removing goal: ${error.message}`);
    }
  }
  async removeAllGoals(roomId) {
    const { error } = await this.supabase.from("goals").delete().eq("roomId", roomId);
    if (error) {
      throw new Error(`Error removing goals: ${error.message}`);
    }
  }
  async getRoomsForParticipant(userId) {
    const { data, error } = await this.supabase.from("participants").select("roomId").eq("userId", userId);
    if (error) {
      throw new Error(
        `Error getting rooms by participant: ${error.message}`
      );
    }
    return data.map((row) => row.roomId);
  }
  async getRoomsForParticipants(userIds) {
    const { data, error } = await this.supabase.from("participants").select("roomId").in("userId", userIds);
    if (error) {
      throw new Error(
        `Error getting rooms by participants: ${error.message}`
      );
    }
    return [...new Set(data.map((row) => row.roomId))];
  }
  async createRoom(roomId) {
    roomId = roomId ?? uuid();
    const { data, error } = await this.supabase.rpc("create_room", {
      roomId
    });
    if (error) {
      throw new Error(`Error creating room: ${error.message}`);
    }
    if (!data || data.length === 0) {
      throw new Error("No data returned from room creation");
    }
    return data[0].id;
  }
  async removeRoom(roomId) {
    const { error } = await this.supabase.from("rooms").delete().eq("id", roomId);
    if (error) {
      throw new Error(`Error removing room: ${error.message}`);
    }
  }
  async addParticipant(userId, roomId) {
    const { error } = await this.supabase.from("participants").insert({ userId, roomId });
    if (error) {
      elizaLogger.error(`Error adding participant: ${error.message}`);
      return false;
    }
    return true;
  }
  async removeParticipant(userId, roomId) {
    const { error } = await this.supabase.from("participants").delete().eq("userId", userId).eq("roomId", roomId);
    if (error) {
      elizaLogger.error(`Error removing participant: ${error.message}`);
      return false;
    }
    return true;
  }
  async createRelationship(params) {
    const allRoomData = await this.getRoomsForParticipants([
      params.userA,
      params.userB
    ]);
    let roomId;
    if (!allRoomData || allRoomData.length === 0) {
      const { data: newRoomData, error: roomsError } = await this.supabase.from("rooms").insert({}).single();
      if (roomsError) {
        throw new Error("Room creation error: " + roomsError.message);
      }
      roomId = newRoomData?.id;
    } else {
      roomId = allRoomData[0];
    }
    const { error: participantsError } = await this.supabase.from("participants").insert([
      { userId: params.userA, roomId },
      { userId: params.userB, roomId }
    ]);
    if (participantsError) {
      throw new Error(
        "Participants creation error: " + participantsError.message
      );
    }
    const { error: relationshipError } = await this.supabase.from("relationships").upsert({
      userA: params.userA,
      userB: params.userB,
      userId: params.userA,
      status: "FRIENDS"
    }).eq("userA", params.userA).eq("userB", params.userB);
    if (relationshipError) {
      throw new Error(
        "Relationship creation error: " + relationshipError.message
      );
    }
    return true;
  }
  async getRelationship(params) {
    const { data, error } = await this.supabase.rpc("get_relationship", {
      usera: params.userA,
      userb: params.userB
    });
    if (error) {
      throw new Error(error.message);
    }
    return data[0];
  }
  async getRelationships(params) {
    const { data, error } = await this.supabase.from("relationships").select("*").or(`userA.eq.${params.userId},userB.eq.${params.userId}`).eq("status", "FRIENDS");
    if (error) {
      throw new Error(error.message);
    }
    return data;
  }
  async getCache(params) {
    const { data, error } = await this.supabase.from("cache").select("value").eq("key", params.key).eq("agentId", params.agentId).single();
    if (error) {
      elizaLogger.error("Error fetching cache:", error);
      return void 0;
    }
    return data?.value;
  }
  async setCache(params) {
    const { error } = await this.supabase.from("cache").upsert({
      key: params.key,
      agentId: params.agentId,
      value: params.value,
      createdAt: /* @__PURE__ */ new Date()
    });
    if (error) {
      elizaLogger.error("Error setting cache:", error);
      return false;
    }
    return true;
  }
  async deleteCache(params) {
    try {
      const { error } = await this.supabase.from("cache").delete().eq("key", params.key).eq("agentId", params.agentId);
      if (error) {
        elizaLogger.error("Error deleting cache", {
          error: error.message,
          key: params.key,
          agentId: params.agentId
        });
        return false;
      }
      return true;
    } catch (error) {
      elizaLogger.error(
        "Database connection error in deleteCache",
        error instanceof Error ? error.message : String(error)
      );
      return false;
    }
  }
  async getKnowledge(params) {
    let query = this.supabase.from("knowledge").select("*").or(`agentId.eq.${params.agentId},isShared.eq.true`);
    if (params.id) {
      query = query.eq("id", params.id);
    }
    if (params.limit) {
      query = query.limit(params.limit);
    }
    const { data, error } = await query;
    if (error) {
      throw new Error(`Error getting knowledge: ${error.message}`);
    }
    return data.map((row) => ({
      id: row.id,
      agentId: row.agentId,
      content: typeof row.content === "string" ? JSON.parse(row.content) : row.content,
      embedding: row.embedding ? new Float32Array(row.embedding) : void 0,
      createdAt: new Date(row.createdAt).getTime()
    }));
  }
  async searchKnowledge(params) {
    const cacheKey = `embedding_${params.agentId}_${params.searchText}`;
    const cachedResult = await this.getCache({
      key: cacheKey,
      agentId: params.agentId
    });
    if (cachedResult) {
      return JSON.parse(cachedResult);
    }
    const embedding = Array.from(params.embedding);
    const { data, error } = await this.supabase.rpc("search_knowledge", {
      query_embedding: embedding,
      query_agent_id: params.agentId,
      match_threshold: params.match_threshold,
      match_count: params.match_count,
      search_text: params.searchText || ""
    });
    if (error) {
      throw new Error(`Error searching knowledge: ${error.message}`);
    }
    const results = data.map((row) => ({
      id: row.id,
      agentId: row.agentId,
      content: typeof row.content === "string" ? JSON.parse(row.content) : row.content,
      embedding: row.embedding ? new Float32Array(row.embedding) : void 0,
      createdAt: new Date(row.createdAt).getTime(),
      similarity: row.similarity
    }));
    await this.setCache({
      key: cacheKey,
      agentId: params.agentId,
      value: JSON.stringify(results)
    });
    return results;
  }
  async createKnowledge(knowledge) {
    try {
      const metadata = knowledge.content.metadata || {};
      const { error } = await this.supabase.from("knowledge").insert({
        id: knowledge.id,
        agentId: metadata.isShared ? null : knowledge.agentId,
        content: knowledge.content,
        embedding: knowledge.embedding ? Array.from(knowledge.embedding) : null,
        createdAt: knowledge.createdAt || /* @__PURE__ */ new Date(),
        isMain: metadata.isMain || false,
        originalId: metadata.originalId || null,
        chunkIndex: metadata.chunkIndex || null,
        isShared: metadata.isShared || false
      });
      if (error) {
        if (metadata.isShared && error.code === "23505") {
          elizaLogger.info(
            `Shared knowledge ${knowledge.id} already exists, skipping`
          );
          return;
        }
        throw error;
      }
    } catch (error) {
      elizaLogger.error(`Error creating knowledge ${knowledge.id}:`, {
        error,
        embeddingLength: knowledge.embedding?.length,
        content: knowledge.content
      });
      throw error;
    }
  }
  async removeKnowledge(id) {
    const { error } = await this.supabase.from("knowledge").delete().eq("id", id);
    if (error) {
      throw new Error(`Error removing knowledge: ${error.message}`);
    }
  }
  async clearKnowledge(agentId, shared) {
    if (shared) {
      const { error } = await this.supabase.from("knowledge").delete().filter("agentId", "eq", agentId).filter("isShared", "eq", true);
      if (error) {
        elizaLogger.error(
          `Error clearing shared knowledge for agent ${agentId}:`,
          error
        );
        throw error;
      }
    } else {
      const { error } = await this.supabase.from("knowledge").delete().eq("agentId", agentId);
      if (error) {
        elizaLogger.error(
          `Error clearing knowledge for agent ${agentId}:`,
          error
        );
        throw error;
      }
    }
  }
};
export {
  SupabaseDatabaseAdapter
};
//# sourceMappingURL=index.js.map