const std = @import("std");
const Io = std.Io;

const tictactoe_qlearning = @import("tictactoe_qlearning");

const rl = @import("raylib");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 500;
    const screenHeight = 500;

    rl.initWindow(screenWidth, screenHeight, "tictactoe-qlearning");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        // First row
        rl.drawRectangleLines(175, 175, 50, 50, .dark_brown);
        rl.drawRectangleLines(225, 175, 50, 50, .dark_brown);
        rl.drawRectangleLines(275, 175, 50, 50, .dark_brown);

        // Second row
        rl.drawRectangleLines(175, 225, 50, 50, .dark_brown);
        rl.drawRectangleLines(225, 225, 50, 50, .dark_brown);
        rl.drawRectangleLines(275, 225, 50, 50, .dark_brown);

        // Third row
        rl.drawRectangleLines(175, 275, 50, 50, .dark_brown);
        rl.drawRectangleLines(225, 275, 50, 50, .dark_brown);
        rl.drawRectangleLines(275, 275, 50, 50, .dark_brown);

        //----------------------------------------------------------------------------------
    }
}
