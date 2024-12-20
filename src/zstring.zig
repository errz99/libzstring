const std = @import("std");
const assert = std.debug.assert;
const allocator = std.heap.c_allocator;
const string = @import("./zig-string.zig");
const String = string.String;

const zstring_t = opaque {};

const zstring_iterator_t = extern struct {
    zstring: ?*const zstring_t,
    index: usize,
};

const zstring_error_t = enum(c_int) {
    ZSTRING_ERROR_NONE,
    ZSTRING_ERROR_OUT_OF_MEMORY,
    ZSTRING_ERROR_INVALID_RANGE,
};

export fn zstring_init() ?*zstring_t {
    const str = allocator.create(String) catch return null;
    str.* = String.init(allocator);
    return @as(*zstring_t, @ptrCast(str));
}

export fn zstring_init_with_contents(contents: ?[*:0]const u8, out_err: ?*zstring_error_t) ?*zstring_t {
    if (contents == null or out_err == null) return null;
    const str = allocator.create(String) catch return null;
    str.* = String.init_with_contents(allocator, std.mem.span(contents.?)) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_OUT_OF_MEMORY;
                }
                return null;
            },
            String.Error.InvalidRange => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_INVALID_RANGE;
                }
                return null;
            },
        }
    };
    if (out_err) |e| {
        e.* = .ZSTRING_ERROR_NONE;
    }
    return @as(*zstring_t, @ptrCast(str));
}

export fn zstring_deinit(self: ?*zstring_t) void {
    if (self) |sf| {
        zstringCast(sf).deinit();
    }
}

export fn zstring_size(self: ?*const zstring_t) usize {
    if (self) |sf| {
        return zstringCast(@constCast(sf)).size;
    }
    return 0;
}

export fn zstring_capacity(self: ?*const zstring_t) usize {
    if (self) |sf| {
        return zstringCast(@constCast(sf)).capacity();
    }
    return 0;
}

export fn zstring_allocate(self: ?*zstring_t, bytes: usize) zstring_error_t {
    zstringCast(self.?).allocate(bytes) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_truncate(self: ?*zstring_t) zstring_error_t {
    zstringCast(self.?).truncate() catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_concat(self: ?*zstring_t, char: ?[*:0]const u8) zstring_error_t {
    zstringCast(self.?).concat(std.mem.span(char.?)) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_insert(self: ?*zstring_t, literal: ?[*:0]const u8, index: usize) zstring_error_t {
    zstringCast(self.?).insert(std.mem.span(literal.?), index) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_pop(self: ?*zstring_t, len: ?*usize) ?[*]const u8 {
    const pop = zstringCast(self.?).pop() orelse return null;
    if (len) |ln| {
        ln.* = pop.len;
    }
    return pop.ptr;
}

export fn zstring_cmp(self: ?*const zstring_t, literal: ?[*:0]const u8) c_int {
    if (zstringCast(@constCast(self.?)).cmp(std.mem.span(literal.?))) return 1;
    return 0;
}

export fn zstring_str(self: ?*const zstring_t, len: ?*usize) ?[*]const u8 {
    const str = zstringCast(@constCast(self.?)).str();
    if (len) |ln| {
        ln.* = str.len;
    }
    return str.ptr;
}

// NOTE: must be freed
export fn zstring_to_owned(self: ?*const zstring_t, out_err: ?*zstring_error_t, len: ?*usize) ?[*]u8 {
    const to_owned = zstringCast(@constCast(self.?)).toOwned() catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_OUT_OF_MEMORY;
                }
                return null;
            },
            String.Error.InvalidRange => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_INVALID_RANGE;
                }
                return null;
            },
        }
    } orelse return null;
    if (out_err) |e| {
        e.* = .ZSTRING_ERROR_NONE;
    }
    if (len) |ln| {
        ln.* = to_owned.len;
    }
    return to_owned.ptr;
}

export fn zstring_char_at(self: ?*const zstring_t, index: usize, len: ?*usize) ?[*]const u8 {
    const char_at = zstringCast(@constCast(self.?)).charAt(index) orelse return null;
    if (len) |ln| {
        ln.* = char_at.len;
    }
    return char_at.ptr;
}

export fn zstring_len(self: ?*const zstring_t) usize {
    return zstringCast(@constCast(self.?)).len();
}

export fn zstring_find(self: ?*const zstring_t, literal: ?[*:0]const u8) usize {
    return zstringCast(@constCast(self.?)).find(std.mem.span(literal.?)) orelse return 0;
}

export fn zstring_remove(self: ?*zstring_t, index: usize) zstring_error_t {
    zstringCast(self.?).remove(index) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_remove_range(self: ?*zstring_t, start: usize, end: usize) zstring_error_t {
    zstringCast(self.?).removeRange(start, end) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_trim_start(self: ?*zstring_t, whitelist: ?[*:0]const u8) void {
    zstringCast(self.?).trimStart(std.mem.span(whitelist.?));
}

export fn zstring_trim_end(self: ?*zstring_t, whitelist: ?[*:0]const u8) void {
    zstringCast(self.?).trimEnd(std.mem.span(whitelist.?));
}

export fn zstring_trim(self: ?*zstring_t, whitelist: ?[*:0]const u8) void {
    zstringCast(self.?).trim(std.mem.span(whitelist.?));
}

export fn zstring_clone(self: ?*const zstring_t, out_err: ?*zstring_error_t) ?*zstring_t {
    const clone = zstringCast(@constCast(self.?)).clone() catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_OUT_OF_MEMORY;
                }
                return null;
            },
            String.Error.InvalidRange => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_INVALID_RANGE;
                }
                return null;
            },
        }
    };
    const str = allocator.create(String) catch return null;
    str.* = clone;
    if (out_err) |e| {
        e.* = .ZSTRING_ERROR_NONE;
    }
    return @as(*zstring_t, @ptrCast(str));
}

export fn zstring_reverse(self: ?*zstring_t) void {
    zstringCast(self.?).reverse();
}

export fn zstring_repeat(self: ?*zstring_t, n: usize) zstring_error_t {
    zstringCast(self.?).repeat(n) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                return .ZSTRING_ERROR_OUT_OF_MEMORY;
            },
            String.Error.InvalidRange => {
                return .ZSTRING_ERROR_INVALID_RANGE;
            },
        }
    };
    return .ZSTRING_ERROR_NONE;
}

export fn zstring_is_empty(self: ?*const zstring_t) c_int {
    if (zstringCast(@constCast(self.?)).isEmpty()) return 1;
    return 0;
}

export fn zstring_split(self: ?*const zstring_t, delimiters: ?[*:0]const u8, index: usize, len: ?*usize) ?[*]const u8 {
    const split = zstringCast(@constCast(self.?)).split(std.mem.span(delimiters.?), index) orelse return null;
    if (len) |ln| {
        ln.* = split.len;
    }
    return split.ptr;
}

export fn zstring_split_to_zstring(self: ?*const zstring_t, delimiters: ?[*:0]const u8, index: usize, out_err: ?*zstring_error_t) ?*zstring_t {
    const clone = zstringCast(@constCast(self.?)).splitToString(std.mem.span(delimiters.?), index) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_OUT_OF_MEMORY;
                }
                return null;
            },
            String.Error.InvalidRange => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_INVALID_RANGE;
                }
                return null;
            },
        }
    } orelse return null;
    const str = allocator.create(String) catch return null;
    str.* = clone;
    if (out_err) |e| {
        e.* = .ZSTRING_ERROR_NONE;
    }
    return @as(*zstring_t, @ptrCast(str));
}

export fn zstring_clear(self: ?*zstring_t) void {
    zstringCast(self.?).clear();
}

export fn zstring_to_lowercase(self: ?*zstring_t) void {
    zstringCast(self.?).toLowercase();
}

export fn zstring_to_uppercase(self: ?*zstring_t) void {
    zstringCast(self.?).toUppercase();
}

export fn zstring_substr(self: ?*const zstring_t, start: usize, end: usize, out_err: ?*zstring_error_t) ?*zstring_t {
    const substr = zstringCast(@constCast(self.?)).substr(start, end) catch |err| {
        switch (err) {
            String.Error.OutOfMemory => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_OUT_OF_MEMORY;
                }
                return null;
            },
            String.Error.InvalidRange => {
                if (out_err) |e| {
                    e.* = .ZSTRING_ERROR_INVALID_RANGE;
                }
                return null;
            },
        }
    };
    const str = allocator.create(String) catch return null;
    str.* = substr;
    if (out_err) |e| {
        e.* = .ZSTRING_ERROR_NONE;
    }
    return @as(*zstring_t, @ptrCast(str));
}

export fn zstring_iterator_next(it: ?*zstring_iterator_t, len: ?*usize) ?[*]const u8 {
    if (zstringCast(@constCast(it.?.*.zstring.?)).buffer) |buffer| {
        if (it.?.*.index == zstringCast(@constCast(it.?.*.zstring.?)).size) return null;
        const i = it.?.*.index;
        it.?.*.index += std.unicode.utf8ByteSequenceLength(buffer[i]) catch 1;
        const buf = buffer[i..it.?.*.index];
        if (len) |ln| {
            ln.* = buf.len;
        }
        return buf.ptr;
    } else {
        return null;
    }
}

export fn zstring_iterator(self: ?*const zstring_t) zstring_iterator_t {
    return .{ .zstring = self, .index = 0 };
}

inline fn zstringCast(zstring: *zstring_t) *String {
    // return @as(*String, @ptrCast(@alignCast(8, zstring));
    return @as(*String, @ptrCast(@alignCast(zstring)));
}

test "Basic Usage" {

    // Create your String
    const myString = zstring_init();
    defer zstring_deinit(myString);

    // Use functions provided
    _ = zstring_concat(myString, "🔥 Hello!");
    var output_len: usize = undefined;
    _ = zstring_pop(myString, &output_len);
    _ = zstring_concat(myString, ", World 🔥");

    // Success!
    assert(zstring_cmp(myString, "🔥 Hello, World 🔥") == 1);
}

test "String Tests" {
    std.debug.print("testing String Tests\n", .{});

    // This is how we create the String
    const myStr = zstring_init();
    defer zstring_deinit(myStr);
    var output_len: usize = undefined;
    var out_err: zstring_error_t = undefined;

    // allocate & capacity
    _ = zstring_allocate(myStr, 16);
    assert(zstring_capacity(myStr) == 16);
    assert(zstring_size(myStr) == 0);

    // truncate
    _ = zstring_truncate(myStr);
    assert(zstring_capacity(myStr) == zstring_size(myStr));
    assert(zstring_capacity(myStr) == 0);

    // concat
    _ = zstring_concat(myStr, "A");
    _ = zstring_concat(myStr, "\u{5360}");
    _ = zstring_concat(myStr, "💯");
    _ = zstring_concat(myStr, "Hello🔥");

    assert(zstring_size(myStr) == 17);

    // pop & length
    assert(zstring_len(myStr) == 9);
    assert(std.mem.eql(u8, zstring_pop(myStr, &output_len).?[0..output_len], "🔥"));
    assert(zstring_len(myStr) == 8);
    assert(std.mem.eql(u8, zstring_pop(myStr, &output_len).?[0..output_len], "o"));
    assert(zstring_len(myStr) == 7);

    // str & cmp
    assert(zstring_cmp(myStr, "A\u{5360}💯Hell") == 1);
    const nstr_1 = try std.testing.allocator.dupeZ(u8, zstring_str(myStr, &output_len).?[0..output_len]);
    defer std.testing.allocator.free(nstr_1);
    assert(zstring_cmp(myStr, nstr_1) == 1);

    // charAt
    assert(std.mem.eql(u8, zstring_char_at(myStr, 2, &output_len).?[0..output_len], "💯"));
    assert(std.mem.eql(u8, zstring_char_at(myStr, 1, &output_len).?[0..output_len], "\u{5360}"));
    assert(std.mem.eql(u8, zstring_char_at(myStr, 0, &output_len).?[0..output_len], "A"));

    // insert
    _ = zstring_insert(myStr, "🔥", 1);
    assert(std.mem.eql(u8, zstring_char_at(myStr, 1, &output_len).?[0..output_len], "🔥"));
    assert(zstring_cmp(myStr, "A🔥\u{5360}💯Hell") == 1);

    // find
    assert(zstring_find(myStr, "🔥") == 1);
    assert(zstring_find(myStr, "💯") == 3);
    assert(zstring_find(myStr, "Hell") == 4);

    // remove & removeRange
    _ = zstring_remove_range(myStr, 0, 3);
    assert(zstring_cmp(myStr, "💯Hell") == 1);
    _ = zstring_remove(myStr, zstring_len(myStr) - 1);
    assert(zstring_cmp(myStr, "💯Hel") == 1);

    const whitelist = [_:0]u8{ ' ', '\t', '\n', '\r' };

    // trimStart
    _ = zstring_insert(myStr, "      ", 0);
    zstring_trim_start(myStr, whitelist[0..]);
    assert(zstring_cmp(myStr, "💯Hel") == 1);

    // trimEnd
    _ = zstring_concat(myStr, "lo💯\n      ");
    zstring_trim_end(myStr, whitelist[0..]);
    assert(zstring_cmp(myStr, "💯Hello💯") == 1);

    // clone
    const testStr = zstring_clone(myStr, &out_err);
    defer zstring_deinit(testStr);
    const nstr_2 = try std.testing.allocator.dupeZ(u8, zstring_str(myStr, &output_len).?[0..output_len]);
    defer std.testing.allocator.free(nstr_2);
    assert(zstring_cmp(testStr, nstr_2) == 1);

    // reverse
    zstring_reverse(myStr);
    assert(zstring_cmp(myStr, "💯olleH💯") == 1);
    zstring_reverse(myStr);
    assert(zstring_cmp(myStr, "💯Hello💯") == 1);

    // repeat
    _ = zstring_repeat(myStr, 2);
    assert(zstring_cmp(myStr, "💯Hello💯💯Hello💯💯Hello💯") == 1);

    // isEmpty
    assert(zstring_is_empty(myStr) == 0);

    // split
    assert(std.mem.eql(u8, zstring_split(myStr, "💯", 0, &output_len).?[0..output_len], ""));
    assert(std.mem.eql(u8, zstring_split(myStr, "💯", 1, &output_len).?[0..output_len], "Hello"));
    assert(std.mem.eql(u8, zstring_split(myStr, "💯", 2, &output_len).?[0..output_len], ""));
    assert(std.mem.eql(u8, zstring_split(myStr, "💯", 3, &output_len).?[0..output_len], "Hello"));
    assert(std.mem.eql(u8, zstring_split(myStr, "💯", 5, &output_len).?[0..output_len], "Hello"));
    assert(std.mem.eql(u8, zstring_split(myStr, "💯", 6, &output_len).?[0..output_len], ""));

    const splitStr = zstring_init();
    defer zstring_deinit(splitStr);

    _ = zstring_concat(splitStr, "variable='value'");
    assert(std.mem.eql(u8, zstring_split(splitStr, "=", 0, &output_len).?[0..output_len], "variable"));
    assert(std.mem.eql(u8, zstring_split(splitStr, "=", 1, &output_len).?[0..output_len], "'value'"));

    // splitToString
    const newSplit = zstring_split_to_zstring(splitStr, "=", 0, &out_err);
    assert(newSplit != null);
    defer zstring_deinit(newSplit);

    assert(std.mem.eql(u8, zstring_str(newSplit, &output_len).?[0..output_len], "variable"));

    // toLowercase & toUppercase
    zstring_to_uppercase(myStr);
    assert(zstring_cmp(myStr, "💯HELLO💯💯HELLO💯💯HELLO💯") == 1);
    zstring_to_lowercase(myStr);
    assert(zstring_cmp(myStr, "💯hello💯💯hello💯💯hello💯") == 1);

    // substr
    const subStr = zstring_substr(myStr, 0, 7, &out_err);
    defer zstring_deinit(subStr);
    assert(zstring_cmp(subStr, "💯hello💯") == 1);

    // clear
    zstring_clear(myStr);
    assert(zstring_len(myStr) == 0);
    assert(zstring_size(myStr) == 0);

    // owned
    _ = zstring_concat(myStr, "This is a Test!");
    const mySlice = zstring_to_owned(myStr, &out_err, &output_len);
    assert(std.mem.eql(u8, mySlice.?[0..output_len], "This is a Test!"));
    allocator.free(mySlice.?[0..output_len]);

    // StringIterator
    var i: usize = 0;
    var iter = zstring_iterator(myStr);
    while (zstring_iterator_next(&iter, &output_len)) |ch| {
        if (i == 0) {
            assert(std.mem.eql(u8, "T", ch[0..output_len]));
        }
        i += 1;
    }

    assert(i == zstring_len(myStr));
}

test "init with contents" {
    const initial_contents = "String with initial contents!";
    var output_len: usize = undefined;
    var out_err: zstring_error_t = undefined;

    // This is how we create the String with contents at the start
    const myStr = zstring_init_with_contents(initial_contents, &out_err);
    assert(std.mem.eql(u8, zstring_str(myStr, &output_len).?[0..output_len], initial_contents));
}
