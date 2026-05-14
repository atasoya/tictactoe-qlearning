const std = @import("std");
const tictactoe = @import("tictactoe.zig");

const Action = struct { u8, u8 };

pub fn randomAction(
    random: std.Random,
    state: *const tictactoe.TicTacToeState,
) Action {
    var possible_actions: [9]Action = undefined;
    var count: usize = 0;

    for (state.board, 0..) |row, i| {
        for (row, 0..) |cell, j| {
            if (cell == 0) {
                possible_actions[count] = .{
                    @intCast(i),
                    @intCast(j),
                };
                count += 1;
            }
        }
    }

    if (count == 0) {
        return .{ 255, 255 };
    }

    const random_index = random.uintLessThan(usize, count);
    return possible_actions[random_index];
}
