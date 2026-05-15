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

    var qAgent = qlearning.Agent.init(allocator);
    defer qAgent.deinit();

    const episodes = 100_000_000;

    var q_wins: usize = 0;
    var random_wins: usize = 0;
    var draws: usize = 0;

    for (0..episodes) |episode| {
        var gameState = tictactoe.TicTacToeState{};

        while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
            if (gameState.current_player == 1) {
                const old_state_key = qlearning.getStateKey(gameState.board);

                const action_index = try qAgent.chooseAction(secureRand, old_state_key);
                const action = qlearning.actionIndexToMove(action_index);

                tictactoe.move(&gameState, action);

                const new_state_key = qlearning.getStateKey(gameState.board);

                const reward = qlearning.rewardFor(
                    gameState.winner,
                    1,
                    tictactoe.isDraw(&gameState),
                );

                try qAgent.update(
                    old_state_key,
                    action_index,
                    reward,
                    new_state_key,
                );
            } else {
                const action = randomAgent.randomAction(secureRand, &gameState);
                tictactoe.move(&gameState, action);
            }
        }

        if (gameState.winner == 1) {
            q_wins += 1;
        } else if (gameState.winner == 2) {
            random_wins += 1;
        } else {
            draws += 1;
        }

        if (episode % 1000 == 0) {
            std.debug.print(
                "Episode {d}: Q wins={d}, Random wins={d}, Draws={d}, Q-table states={d}\n",
                .{
                    episode,
                    q_wins,
                    random_wins,
                    draws,
                    qAgent.q_table.count(),
                },
            );
        }
    }

    std.debug.print("\nTraining finished.\n", .{});
    std.debug.print("Q wins: {d}\n", .{q_wins});
    std.debug.print("Random wins: {d}\n", .{random_wins});
    std.debug.print("Draws: {d}\n", .{draws});
    std.debug.print("Q-table states learned: {d}\n", .{qAgent.q_table.count()});

    std.debug.print("\nOne final game after training:\n", .{});

    qAgent.epsilon = 0.0;

    var finalGame = tictactoe.TicTacToeState{};
    tictactoe.renderBoard(&finalGame);

    while (!tictactoe.isGameWon(&finalGame) and !tictactoe.isDraw(&finalGame)) {
        if (finalGame.current_player == 1) {
            const state_key = qlearning.getStateKey(finalGame.board);
            const action_index = try qAgent.bestAction(state_key);
            const action = qlearning.actionIndexToMove(action_index);

            std.debug.print("Q-agent action: {d}, move: {any}\n", .{ action_index, action });

            tictactoe.move(&finalGame, action);
        } else {
            const action = randomAgent.randomAction(secureRand, &finalGame);

            std.debug.print("Random agent action: {any}\n", .{action});

            tictactoe.move(&finalGame, action);
        }

        tictactoe.renderBoard(&finalGame);
    }

    std.debug.print("Final game winner: {any}\n", .{finalGame.winner});
}

