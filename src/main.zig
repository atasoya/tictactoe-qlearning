const std = @import("std");
const randomAgent = @import("randomAgent.zig");
const tictactoe = @import("tictactoe.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const secureRand = rng_impl.interface();

    var gameState = tictactoe.TicTacToeState{};
    tictactoe.renderBoard(&gameState);

    var action = randomAgent.randomAction(secureRand, &gameState);
    std.debug.print("action: {any}\n", .{action});
    tictactoe.move(&gameState, action);
    tictactoe.renderBoard(&gameState);

    while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
        action = randomAgent.randomAction(secureRand, &gameState);
        std.debug.print("action: {any}\n", .{action});
        tictactoe.move(&gameState, action);
        tictactoe.renderBoard(&gameState);
    }
    std.debug.print("winner: {any}\n", .{gameState.winner});
}

