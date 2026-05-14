const std = @import("std");

pub const TicTacToeState = struct {
    board: [3][3]u8 = [_][3]u8{
        [_]u8{ 0, 0, 0 },
        [_]u8{ 0, 0, 0 },
        [_]u8{ 0, 0, 0 },
    },
    current_player: u8 = 1,
    winner: u8 = 0,
};

pub fn renderBoard(state: *const TicTacToeState) void {
    const b = state.board;
    std.debug.print("│ {d} ", .{b[0][0]});
    std.debug.print("│ {d} ", .{b[0][1]});
    std.debug.print("│ {d}\n", .{b[0][2]});

    std.debug.print("│ {d} ", .{b[1][0]});
    std.debug.print("│ {d} ", .{b[1][1]});
    std.debug.print("│ {d}\n", .{b[1][2]});

    std.debug.print("│ {d} ", .{b[2][0]});
    std.debug.print("│ {d} ", .{b[2][1]});
    std.debug.print("│ {d}\n", .{b[2][2]});
}

pub fn isGameWon(state: *TicTacToeState) bool {
    const b = state.board;

    // Rows
    if (b[0][0] != 0 and b[0][0] == b[0][1] and b[0][0] == b[0][2]) {
        state.winner = b[0][0];
        return true;
    }

    if (b[1][0] != 0 and b[1][0] == b[1][1] and b[1][0] == b[1][2]) {
        state.winner = b[1][0];
        return true;
    }

    if (b[2][0] != 0 and b[2][0] == b[2][1] and b[2][0] == b[2][2]) {
        state.winner = b[2][0];
        return true;
    }

    // Columns
    if (b[0][0] != 0 and b[0][0] == b[1][0] and b[0][0] == b[2][0]) {
        state.winner = b[0][0];
        return true;
    }

    if (b[0][1] != 0 and b[0][1] == b[1][1] and b[0][1] == b[2][1]) {
        state.winner = b[0][1];
        return true;
    }

    if (b[0][2] != 0 and b[0][2] == b[1][2] and b[0][2] == b[2][2]) {
        state.winner = b[0][2];
        return true;
    }

    // Diagonals
    if (b[0][0] != 0 and b[0][0] == b[1][1] and b[0][0] == b[2][2]) {
        state.winner = b[0][0];
        return true;
    }

    if (b[0][2] != 0 and b[0][2] == b[1][1] and b[0][2] == b[2][0]) {
        state.winner = b[0][2];
        return true;
    }

    return false;
}
