const std = @import("std");
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const WIDTH = 800;
const HEIGHT = 600;

const SEEDS_COUNT = 10;
const SEED_MARKER_RADIUS = 10;
const SEED_MARKER_COLOR = .background;

const Color32 = u32;
// https://draculatheme.com
const Palette = enum(Color32) {
    background = 0x282A36,
    current_line = 0x44475A,
    foreground = 0xF8F8F2,
    comment = 0x6272A4,
    cyan = 0x8BE9FD,
    green = 0x50FA7B,
    orange = 0xFFB86C,
    pink = 0xFF79C6,
    purple = 0xBD93F9,
    red = 0xFF5555,
    yellow = 0xF1FA8C,
};

const Point = @Vector(2, i64);

var image: [HEIGHT][WIDTH]Color32 = undefined;
var seeds: [SEEDS_COUNT]Point = undefined;

fn fillImage(color: Palette) void {
    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            image[y][x] = @intFromEnum(color);
        }
    }
}

fn saveImage(file_path: []const u8) !void {
    var file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.writer().print("P6\n{} {} 255\n", .{ WIDTH, HEIGHT });

    var bytes = ArrayList(u8).init(allocator);
    defer bytes.deinit();

    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            const pixel = image[y][x];
            try bytes.appendSlice(&[_]u8{
                @intCast((pixel >> 16) & 0xFF),
                @intCast((pixel >> 8) & 0xFF),
                @intCast(pixel & 0xFF),
            });
        }
    }

    try file.writeAll(bytes.items);
}

fn sqrDist(x1: anytype, y1: anytype, x2: anytype, y2: anytype) i64 {
    const dx = @as(i64, @intCast(x1)) - @as(i64, @intCast(x2));
    const dy = @as(i64, @intCast(y1)) - @as(i64, @intCast(y2));
    return dx * dx + dy * dy;
}

fn fillCircle(cx: i64, cy: i64, radius: i64, color: Palette) void {
    const x0 = cx - radius;
    const y0 = cy - radius;
    const x1 = cx + radius;
    const y1 = cy + radius;

    var x = x0;
    while (x <= x1) : (x += 1) {
        if (x < 0 or x >= WIDTH) break;

        var y = y0;
        while (y <= y1) : (y += 1) {
            if (y < 0 or y >= HEIGHT) break;

            if (sqrDist(cx, cy, x, y) <= radius * radius) {
                image[@intCast(y)][@intCast(x)] = @intFromEnum(color);
            }
        }
    }
}

fn generateRandomSeeds() !void {
    var rng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    for (0..SEEDS_COUNT) |i| {
        seeds[i][0] = @mod(rng.random().int(i64), WIDTH);
        seeds[i][1] = @mod(rng.random().int(i64), HEIGHT);
    }
}

fn renderSeeds() void {
    for (seeds) |seed| {
        fillCircle(seed[0], seed[1], SEED_MARKER_RADIUS, SEED_MARKER_COLOR);
    }
}

fn renderVoronoi() void {
    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            var j: u64 = 0;
            for (1..SEEDS_COUNT) |i| {
                if (sqrDist(seeds[i][0], seeds[i][1], x, y) < sqrDist(seeds[j][0], seeds[j][1], x, y)) {
                    j = i;
                }
            }

            const palette = std.meta.tags(Palette)[1..];
            image[y][x] = @intFromEnum(palette[j % palette.len]);
        }
    }
}

pub fn main() !void {
    fillImage(.background);
    try generateRandomSeeds();
    renderVoronoi();
    renderSeeds();
    try saveImage("output.ppm");
}
