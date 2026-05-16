const std = @import("std");

pub const StateKey = [9]u8;
pub const QValues = [9]f64;
pub const Move = struct { u8, u8 };

pub const QTable = std.AutoHashMap(StateKey, QValues);

pub const Agent = struct {
    q_table: QTable,
    learning_rate: f64,
    discount: f64,
    epsilon: f64,

    pub fn init(allocator: std.mem.Allocator) Agent {
        return Agent{
            .q_table = QTable.init(allocator),
            .learning_rate = 0.1,
            .discount = 0.95,
            .epsilon = 0.2,
        };
    }

    pub fn loadQTableFromJson(
        self: *Agent,
        io: std.Io,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !void {
        const contents = try std.Io.Dir.cwd().readFileAlloc(
            io,
            path,
            allocator,
            .limited(10 * 1024 * 1024),
        );
        defer allocator.free(contents);

        const ParsedMap = std.json.ArrayHashMap(QValues);

        const parsed = try std.json.parseFromSlice(
            ParsedMap,
            allocator,
            contents,
            .{},
        );
        defer parsed.deinit();

        var iterator = parsed.value.map.iterator();

        while (iterator.next()) |entry| {
            const key_string = entry.key_ptr.*;
            const q_values = entry.value_ptr.*;

            if (key_string.len != 9) {
                continue;
            }

            var state_key: StateKey = undefined;

            for (key_string, 0..) |char, i| {
                if (char < '0' or char > '2') {
                    continue;
                }

                state_key[i] = char - '0';
            }

            try self.q_table.put(state_key, q_values);
        }

        std.debug.print("Loaded Q-table states: {d}\n", .{self.q_table.count()});
    }

    pub fn saveQTableToJson(self: *const Agent, io: std.Io, path: []const u8) !void {
        var file = try std.Io.Dir.cwd().createFile(io, path, .{
            .truncate = true,
        });
        defer file.close(io);

        var buffer: [4096]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        const writer = &file_writer.interface;

        try writer.writeAll("{\n");

        var iterator = self.q_table.iterator();
        var first_entry = true;

        while (iterator.next()) |entry| {
            const state: StateKey = entry.key_ptr.*;
            const q_values: QValues = entry.value_ptr.*;

            if (!first_entry) {
                try writer.writeAll(",\n");
            }

            first_entry = false;

            try writer.writeAll("  \"");

            for (state) |cell| {
                try writer.print("{d}", .{cell});
            }

            try writer.writeAll("\": [");

            for (q_values, 0..) |q, i| {
                if (i != 0) {
                    try writer.writeAll(", ");
                }

                try writer.print("{d}", .{q});
            }

            try writer.writeAll("]");
        }

        try writer.writeAll("\n}\n");

        try writer.flush();
    }

    pub fn deinit(self: *Agent) void {
        self.q_table.deinit();
    }

    pub fn getQValues(self: *Agent, state_key: StateKey) !*QValues {
        const entry = try self.q_table.getOrPut(state_key);

        if (!entry.found_existing) {
            entry.value_ptr.* = [_]f64{0.0} ** 9;
        }

        return entry.value_ptr;
    }

    pub fn bestAction(self: *Agent, state_key: StateKey) !usize {
        const q_values = try self.getQValues(state_key);

        var best_action: usize = 0;
        var best_value: f64 = -999999.0;
        var found = false;

        for (state_key, 0..) |cell, action| {
            if (cell == 0) {
                if (!found or q_values[action] > best_value) {
                    best_value = q_values[action];
                    best_action = action;
                    found = true;
                }
            }
        }

        return best_action;
    }

    pub fn randomLegalAction(
        self: *Agent,
        rng: std.Random,
        state_key: StateKey,
    ) usize {
        _ = self;

        var legal_actions: [9]usize = undefined;
        var legal_count: usize = 0;

        for (state_key, 0..) |cell, action| {
            if (cell == 0) {
                legal_actions[legal_count] = action;
                legal_count += 1;
            }
        }

        const index = rng.uintLessThan(usize, legal_count);
        return legal_actions[index];
    }

    pub fn chooseAction(
        self: *Agent,
        rng: std.Random,
        state_key: StateKey,
    ) !usize {
        const explore_value = rng.float(f64);

        if (explore_value < self.epsilon) {
            return self.randomLegalAction(rng, state_key);
        }

        return try self.bestAction(state_key);
    }

    fn maxFutureQ(self: *Agent, state_key: StateKey) !f64 {
        const q_values = try self.getQValues(state_key);

        var best_value: f64 = -999999.0;
        var found = false;

        for (state_key, 0..) |cell, action| {
            if (cell == 0) {
                if (!found or q_values[action] > best_value) {
                    best_value = q_values[action];
                    found = true;
                }
            }
        }

        if (!found) {
            return 0.0;
        }

        return best_value;
    }

    pub fn update(
        self: *Agent,
        old_state: StateKey,
        action: usize,
        reward: f64,
        new_state: StateKey,
    ) !void {
        // First calculate future Q.
        // This may insert into the hashmap.
        const best_future_q = try self.maxFutureQ(new_state);

        // After all possible hashmap insertions, get old state pointer.
        const old_q_values = try self.getQValues(old_state);

        const old_q = old_q_values[action];

        old_q_values[action] =
            old_q + self.learning_rate * (reward + self.discount * best_future_q - old_q);
    }
};

pub fn getStateKey(board: [3][3]u8) StateKey {
    return StateKey{
        board[0][0], board[0][1], board[0][2],
        board[1][0], board[1][1], board[1][2],
        board[2][0], board[2][1], board[2][2],
    };
}

pub fn actionIndexToMove(action: usize) Move {
    return .{
        @intCast(action / 3),
        @intCast(action % 3),
    };
}

pub fn rewardFor(winner: u8, agent_player: u8, is_draw: bool) f64 {
    if (winner == agent_player) {
        return 1.0;
    }

    if (winner != 0 and winner != agent_player) {
        return -1.0;
    }

    if (is_draw) {
        return 0.3;
    }

    return 0.0;
}

