const std = @import("std");

const tictactoe = @import("tictactoe.zig");

pub fn main() !void {
    var ticTacToeGame = tictactoe.TicTacToeState{};

    tictactoe.renderBoard(&ticTacToeGame);

    std.debug.print("is game won: {}\n", .{tictactoe.isGameWon(&ticTacToeGame)});
}
