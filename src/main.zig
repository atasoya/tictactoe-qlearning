const std = @import("std");
const randomAgent = @import("randomAgent.zig");
const tictactoe = @import("tictactoe.zig");
const qlearning = @import("qlearning.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const secureRand = rng_impl.interface();

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    var qAgent = qlearning.Agent.init(allocator);
    defer qAgent.deinit();

    const episodes = 2_000_000;

    if (std.mem.eql(u8, command, "train")) {
        try train(episodes, &qAgent, secureRand, io);
        return;
    }

    if (std.mem.eql(u8, command, "evaluate")) {
        try qAgent.loadQTableFromJson(io, allocator, "q_table.json");
        try evaluate(&qAgent, secureRand);
        return;
    }

    if (std.mem.eql(u8, command, "play")) {
        try qAgent.loadQTableFromJson(io, allocator, "q_table.json");
        try playAgainstAgent(io, &qAgent);
        return;
    }

    if (std.mem.eql(u8, command, "all")) {
        try train(episodes, &qAgent, secureRand, io);

        qAgent.deinit();
        qAgent = qlearning.Agent.init(allocator);

        try qAgent.loadQTableFromJson(io, allocator, "q_table.json");

        try evaluate(&qAgent, secureRand);
        try playAgainstAgent(io, &qAgent);
        return;
    }

    std.debug.print("Unknown command: {s}\n\n", .{command});
    printUsage();
}

pub fn train(
    episodes: usize,
    qAgent: *qlearning.Agent,
    secureRand: std.Random,
    io: std.Io,
) !void {
    var q_wins: usize = 0;
    var random_wins: usize = 0;
    var draws: usize = 0;

    for (0..episodes) |episode| {
        var gameState = tictactoe.TicTacToeState{};

        const q_agent_player: u8 = if (episode % 2 == 0) 1 else 2;
        const random_player: u8 = if (q_agent_player == 1) 2 else 1;

        while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
            if (gameState.current_player == q_agent_player) {
                // Save state before Q-agent move
                const old_state_key = qlearning.getStateKey(gameState.board);

                const action_index = try qAgent.chooseAction(secureRand, old_state_key);
                const action = qlearning.actionIndexToMove(action_index);

                tictactoe.move(&gameState, action);

                // Case 1: Q-agent wins or draws immediately
                if (tictactoe.isGameWon(&gameState) or tictactoe.isDraw(&gameState)) {
                    const new_state_key = qlearning.getStateKey(gameState.board);

                    const reward = qlearning.rewardFor(
                        gameState.winner,
                        q_agent_player,
                        tictactoe.isDraw(&gameState),
                    );

                    try qAgent.update(
                        old_state_key,
                        action_index,
                        reward,
                        new_state_key,
                    );

                    break;
                }

                // Case 2: random opponent replies
                const random_action = randomAgent.randomAction(secureRand, &gameState);
                tictactoe.move(&gameState, random_action);

                // Now update Q-agent after seeing opponent response
                const new_state_key = qlearning.getStateKey(gameState.board);

                const reward = qlearning.rewardFor(
                    gameState.winner,
                    q_agent_player,
                    tictactoe.isDraw(&gameState),
                );

                try qAgent.update(
                    old_state_key,
                    action_index,
                    reward,
                    new_state_key,
                );
            } else {
                // This happens when Q-agent is player 2 and random starts.
                const random_action = randomAgent.randomAction(secureRand, &gameState);
                tictactoe.move(&gameState, random_action);
            }
        }

        if (gameState.winner == q_agent_player) {
            q_wins += 1;
        } else if (gameState.winner == random_player) {
            random_wins += 1;
        } else {
            draws += 1;
        }

        if (episode % 1000 == 0) {
            std.debug.print(
                "Episode {d}: Q wins={d}, Random wins={d}, Draws={d}, Q-table states={d}, epsilon={d:.3}, Q-player={d}\n",
                .{
                    episode,
                    q_wins,
                    random_wins,
                    draws,
                    qAgent.q_table.count(),
                    qAgent.epsilon,
                    q_agent_player,
                },
            );
        }
    }

    std.debug.print("\nTraining finished.\n", .{});
    std.debug.print("Q wins: {d}\n", .{q_wins});
    std.debug.print("Random wins: {d}\n", .{random_wins});
    std.debug.print("Draws: {d}\n", .{draws});
    std.debug.print("Q-table states learned: {d}\n", .{qAgent.q_table.count()});

    try qAgent.saveQTableToJson(io, "q_table.json");
}

pub fn evaluate(qAgent: *qlearning.Agent, secureRand: std.Random) !void {
    qAgent.epsilon = 0.0;

    var eval_q_wins: usize = 0;
    var eval_random_wins: usize = 0;
    var eval_draws: usize = 0;

    const eval_games = 10_000;

    for (0..eval_games) |game| {
        var gameState = tictactoe.TicTacToeState{};

        const q_agent_player: u8 = if (game % 2 == 0) 1 else 2;
        const random_player: u8 = if (q_agent_player == 1) 2 else 1;

        while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
            if (gameState.current_player == q_agent_player) {
                const state_key = qlearning.getStateKey(gameState.board);
                const action_index = try qAgent.bestAction(state_key);
                const action = qlearning.actionIndexToMove(action_index);

                tictactoe.move(&gameState, action);
            } else {
                const action = randomAgent.randomAction(secureRand, &gameState);
                tictactoe.move(&gameState, action);
            }
        }

        if (gameState.winner == q_agent_player) {
            eval_q_wins += 1;
        } else if (gameState.winner == random_player) {
            eval_random_wins += 1;
        } else {
            eval_draws += 1;
        }
    }

    const eval_q_win_rate =
        @as(f64, @floatFromInt(eval_q_wins)) / @as(f64, @floatFromInt(eval_games)) * 100.0;

    const eval_random_win_rate =
        @as(f64, @floatFromInt(eval_random_wins)) / @as(f64, @floatFromInt(eval_games)) * 100.0;

    const eval_draw_rate =
        @as(f64, @floatFromInt(eval_draws)) / @as(f64, @floatFromInt(eval_games)) * 100.0;

    std.debug.print("\nEvaluation after training:\n", .{});
    std.debug.print("Q wins: {d} ({d:.2}%)\n", .{ eval_q_wins, eval_q_win_rate });
    std.debug.print("Random wins: {d} ({d:.2}%)\n", .{ eval_random_wins, eval_random_win_rate });
    std.debug.print("Draws: {d} ({d:.2}%)\n", .{ eval_draws, eval_draw_rate });
    std.debug.print("Q-table states learned: {d}\n", .{qAgent.q_table.count()});
}

fn renderHumanBoard(state: *const tictactoe.TicTacToeState) void {
    std.debug.print("\n", .{});

    for (0..3) |row| {
        for (0..3) |col| {
            const cell = state.board[row][col];

            const symbol: u8 = switch (cell) {
                0 => '0' + @as(u8, @intCast(row * 3 + col)),
                1 => 'X',
                2 => 'O',
                else => '?',
            };

            std.debug.print(" {c} ", .{symbol});

            if (col < 2) {
                std.debug.print("|", .{});
            }
        }

        std.debug.print("\n", .{});

        if (row < 2) {
            std.debug.print("---+---+---\n", .{});
        }
    }

    std.debug.print("\n", .{});
}

fn readHumanAction(io: std.Io, state: *const tictactoe.TicTacToeState) !usize {
    var stdin_buffer: [128]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buffer);

    while (true) {
        std.debug.print("Choose a move 0-8: ", .{});

        const line = stdin_reader.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.EndOfStream => {
                std.debug.print("\nEnd of input.\n", .{});
                return err;
            },
            else => return err,
        };

        const trimmed = std.mem.trim(u8, line, " \t\r\n");

        const action = std.fmt.parseInt(usize, trimmed, 10) catch {
            std.debug.print("Invalid input. Enter a number from 0 to 8.\n", .{});
            continue;
        };

        if (action >= 9) {
            std.debug.print("Move must be between 0 and 8.\n", .{});
            continue;
        }

        const row = action / 3;
        const col = action % 3;

        if (state.board[row][col] != 0) {
            std.debug.print("That cell is already taken.\n", .{});
            continue;
        }

        return action;
    }
}

pub fn playAgainstAgent(io: std.Io, qAgent: *qlearning.Agent) !void {
    qAgent.epsilon = 0.0;

    var gameState = tictactoe.TicTacToeState{};

    const human_player: u8 = 1;
    const agent_player: u8 = 2;

    std.debug.print("\nPlay against Q-agent!\n", .{});
    std.debug.print("You are X. Agent is O.\n", .{});
    std.debug.print("Use numbers 0-8 to choose a cell.\n", .{});

    while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
        renderHumanBoard(&gameState);

        if (gameState.current_player == human_player) {
            const human_action_index = try readHumanAction(io, &gameState);
            const human_move = qlearning.actionIndexToMove(human_action_index);

            tictactoe.move(&gameState, human_move);
        } else {
            const state_key = qlearning.getStateKey(gameState.board);
            const agent_action_index = try qAgent.bestAction(state_key);
            const agent_move = qlearning.actionIndexToMove(agent_action_index);

            std.debug.print("Agent chooses: {d}\n", .{agent_action_index});

            tictactoe.move(&gameState, agent_move);
        }
    }

    renderHumanBoard(&gameState);

    if (gameState.winner == human_player) {
        std.debug.print("You win!\n", .{});
    } else if (gameState.winner == agent_player) {
        std.debug.print("Agent wins!\n", .{});
    } else {
        std.debug.print("Draw!\n", .{});
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  zig build run -- train
        \\  zig build run -- evaluate
        \\  zig build run -- play
        \\  zig build run -- all
        \\
        \\Commands:
        \\  train                Train Q-agent and save q_table.json
        \\  evaluate             Load q_table.json and evaluate agent
        \\  play                 Load q_table.json and play against agent
        \\  all                  Train, reload from q_table.json, evaluate, then play
        \\
    , .{});
}
