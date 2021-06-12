pub const VGA_WIDTH = 80;

pub const VGA_HEIGHT = 25;

pub const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

pub const Colour = enum(u8) {
    black,
    blue,
    green,
    cyan,
    red,
    magenta,
    brown,
    light_grey,
    light_blue,
    light_green,
    light_cyan,
    light_red,
    light_magenta,
    light_brown,
    white,
};

pub const ColourCode = packed struct {
    colour: u8,

    pub fn init(foreground: Colour, background: Colour) ColourCode {
        return ColourCode{ .colour = (@enumToInt(background) << 4) | @enumToInt(foreground) };
    }
};

pub const ScreenChar = packed struct {
    char: u8,
    colour_code: ColourCode,

    pub fn init(char: u8, colour_code: ColourCode) ScreenChar {
        return ScreenChar{ .char = char, .colour_code = colour_code };
    }
};
