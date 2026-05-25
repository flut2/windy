const std = @import("std");

const windy = @import("../windy.zig");
const Error = @import("errors.zig").GtkError;

fn windyRgbaToGdk(color: windy.Rgba) GdkRgba {
    return .{
        .r = @as(f64, @floatFromInt(color.r)) / 255.0,
        .g = @as(f64, @floatFromInt(color.g)) / 255.0,
        .b = @as(f64, @floatFromInt(color.b)) / 255.0,
        .a = @as(f64, @floatFromInt(color.a)) / 255.0,
    };
}

fn gdkRgbaToWindy(color: GdkRgba) windy.Rgba {
    return .{
        .r = @intFromFloat(color.r * 255.0),
        .g = @intFromFloat(color.g * 255.0),
        .b = @intFromFloat(color.b * 255.0),
        .a = @intFromFloat(color.a * 255.0),
    };
}

fn appendFileFilters(dialog: *anyopaque, filters: []const windy.SentinelFilter) void {
    for (filters) |f| {
        const filter = gtk_file_filter_new();
        gtk_file_filter_set_name(filter, f.name);
        if (f.exts) |exts| for (exts) |ext|
            gtk_file_filter_add_pattern(filter, ext);
        gtk_file_chooser_add_filter(dialog, filter);
    }
}

fn wait() void {
    while (gdk_events_pending() != 0)
        _ = gtk_main_iteration();
}

pub fn openDialog(
    comptime multiple_selection: bool,
    _: std.mem.Allocator,
    child_allocator: std.mem.Allocator,
    _: std.Io,
    dialog_type: windy.DialogType,
    filters: []const windy.SentinelFilter,
    title: [:0]const u8,
    default_path: ?[:0]const u8,
) Error!if (multiple_selection) []const []const u8 else []const u8 {
    var dummy: i32 = 0;
    if (gdk_init_check(&dummy, null) == 0) return Error.Initialize;

    const dialog = gtk_file_chooser_dialog_new(
        title,
        null,
        if (dialog_type == .directory) .select_folder else .open,
        "_Cancel",
        @intFromEnum(ResponseType.cancel),
        "_Open",
        @intFromEnum(ResponseType.accept),
        @as(usize, 0),
    );
    defer {
        gtk_widget_destroy(dialog);
        wait();
    }

    if (multiple_selection) gtk_file_chooser_set_select_multiple(dialog, 1);
    if (default_path) |path| _ = gtk_file_chooser_set_current_folder(dialog, path);
    appendFileFilters(dialog, filters);

    if (gtk_dialog_run(dialog) != .accept)
        return &.{};

    if (!multiple_selection) {
        const path = gtk_file_chooser_get_filename(dialog) orelse return &.{};
        defer g_free(path);
        return child_allocator.dupe(u8, std.mem.span(path));
    }

    var ret: std.ArrayList([]const u8) = .empty;
    const file_list = gtk_file_chooser_get_filenames(dialog);
    defer g_slist_free(file_list);

    var cur_list: ?*SList = file_list;
    while (cur_list) |list| {
        defer cur_list = list.f_next;

        const data = list.f_data orelse continue;
        defer g_free(data);

        const str: [*:0]const u8 = @ptrCast(data);
        try ret.append(child_allocator, try child_allocator.dupe(u8, std.mem.span(str)));
    }

    return try ret.toOwnedSlice(child_allocator);
}

pub fn saveDialog(
    _: std.mem.Allocator,
    child_allocator: std.mem.Allocator,
    _: std.Io,
    filters: []const windy.SentinelFilter,
    title: [:0]const u8,
    default_path: ?[:0]const u8,
) Error![]const u8 {
    var dummy: i32 = 0;
    if (gdk_init_check(&dummy, null) == 0) return Error.Initialize;

    const dialog = gtk_file_chooser_dialog_new(
        title,
        null,
        .save,
        "_Cancel",
        @intFromEnum(ResponseType.cancel),
        "_Save",
        @intFromEnum(ResponseType.accept),
        @as(usize, 0),
    );
    defer {
        gtk_widget_destroy(dialog);
        wait();
    }

    gtk_file_chooser_set_do_overwrite_confirmation(dialog, 1);
    if (default_path) |path| _ = gtk_file_chooser_set_current_folder(dialog, path);
    appendFileFilters(dialog, filters);

    if (gtk_dialog_run(dialog) != .accept)
        return &.{};

    const path = gtk_file_chooser_get_filename(dialog) orelse return &.{};
    defer g_free(path);
    return try child_allocator.dupe(u8, std.mem.span(path));
}

pub fn message(
    _: std.mem.Allocator,
    _: std.Io,
    level: windy.MessageLevel,
    buttons: windy.MessageButtons,
    text: [:0]const u8,
    title: [:0]const u8,
) Error!bool {
    var dummy: i32 = 0;
    if (gdk_init_check(&dummy, null) == 0) return Error.Initialize;

    const dialog = gtk_message_dialog_new(
        null,
        .{ .modal = true, .destroy_with_parent = true },
        switch (level) {
            .info => .info,
            .warn => .warning,
            .err => .@"error",
        },
        switch (buttons) {
            .yes_no => .yes_no,
            .ok_cancel => .ok_cancel,
            .ok => .ok,
        },
        "%s",
        text.ptr,
    );
    defer {
        gtk_widget_destroy(dialog);
        wait();
    }

    gtk_window_set_title(dialog, title);

    const run_res = gtk_dialog_run(dialog);
    return run_res == .ok or run_res == .yes;
}

pub fn colorChooser(
    _: std.mem.Allocator,
    _: std.Io,
    color: windy.Rgba,
    use_alpha: bool,
    title: [:0]const u8,
) Error!?windy.Rgba {
    var dummy: i32 = 0;
    if (gdk_init_check(&dummy, null) == 0) return Error.Initialize;

    const dialog = gtk_color_chooser_dialog_new(title, null);
    defer {
        gtk_widget_destroy(dialog);
        wait();
    }

    gtk_color_chooser_set_use_alpha(dialog, @intFromBool(use_alpha));
    gtk_color_chooser_set_rgba(dialog, &windyRgbaToGdk(color));

    if (gtk_dialog_run(dialog) != .ok)
        return null;

    var gdk_color: GdkRgba = .invalid;
    gtk_color_chooser_get_rgba(dialog, &gdk_color);
    return gdkRgbaToWindy(gdk_color);
}

const GdkRgba = extern struct {
    const invalid: GdkRgba = .{
        .r = std.math.nan(f64),
        .g = std.math.nan(f64),
        .b = std.math.nan(f64),
        .a = std.math.nan(f64),
    };

    r: f64,
    g: f64,
    b: f64,
    a: f64,
};

const SList = extern struct {
    f_data: ?*anyopaque,
    f_next: ?*SList,
};

const ResponseType = enum(i32) {
    none = -1,
    reject = -2,
    accept = -3,
    delete_event = -4,
    ok = -5,
    cancel = -6,
    close = -7,
    yes = -8,
    no = -9,
    apply = -10,
    help = -11,
    _,
};

const FileChooserAction = enum(i32) {
    open = 0,
    save = 1,
    select_folder = 2,
    create_folder = 3,
    _,
};

pub const MessageType = enum(i32) {
    info = 0,
    warning = 1,
    question = 2,
    @"error" = 3,
    other = 4,
    _,
};

pub const ButtonsType = enum(i32) {
    none = 0,
    ok = 1,
    close = 2,
    cancel = 3,
    yes_no = 4,
    ok_cancel = 5,
    _,
};

pub const DialogFlags = packed struct(u32) {
    modal: bool = false,
    destroy_with_parent: bool = false,
    use_header_bar: bool = false,
    padding: u29 = 0,
};

extern fn gtk_main_iteration() c_int;

extern fn gdk_events_pending() c_int;
extern fn gdk_init_check(p_argc: *c_int, p_argv: ?*[*][*:0]u8) c_int;

extern fn gtk_widget_destroy(p_widget: *anyopaque) void;
extern fn gtk_dialog_run(p_dialog: *anyopaque) ResponseType;

extern fn gtk_file_chooser_dialog_new(
    p_title: ?[*:0]const u8,
    p_parent: ?*anyopaque,
    p_action: FileChooserAction,
    p_first_button_text: ?[*:0]const u8,
    ...,
) *anyopaque;
extern fn gtk_file_chooser_get_filename(p_chooser: *anyopaque) ?[*:0]u8;
extern fn gtk_file_chooser_get_filenames(p_chooser: *anyopaque) *SList;
extern fn gtk_file_chooser_set_select_multiple(p_chooser: *anyopaque, p_select_multiple: c_int) void;
extern fn gtk_file_chooser_set_current_folder(p_chooser: *anyopaque, p_filename: [*:0]const u8) c_int;
extern fn gtk_file_chooser_set_do_overwrite_confirmation(p_chooser: *anyopaque, p_do_overwrite_confirmation: c_int) void;

extern fn gtk_file_filter_new() *anyopaque;
extern fn gtk_file_filter_set_name(p_filter: *anyopaque, p_name: ?[*:0]const u8) void;
extern fn gtk_file_filter_add_pattern(p_filter: *anyopaque, p_pattern: [*:0]const u8) void;
extern fn gtk_file_chooser_add_filter(p_chooser: *anyopaque, p_filter: *anyopaque) void;

extern fn gtk_message_dialog_new(
    p_parent: ?*anyopaque,
    p_flags: DialogFlags,
    p_type: MessageType,
    p_buttons: ButtonsType,
    p_message_format: ?[*:0]const u8,
    ...,
) *anyopaque;
extern fn gtk_window_set_title(p_window: *anyopaque, p_title: [*:0]const u8) void;

extern fn gtk_color_chooser_dialog_new(p_title: ?[*:0]const u8, p_parent: ?*anyopaque) *anyopaque;
extern fn gtk_color_chooser_set_use_alpha(p_chooser: *anyopaque, p_use_alpha: c_int) void;
extern fn gtk_color_chooser_set_rgba(p_chooser: *anyopaque, p_color: *const GdkRgba) void;
extern fn gtk_color_chooser_get_rgba(p_chooser: *anyopaque, p_color: *GdkRgba) void;

extern fn g_free(p_mem: ?*anyopaque) void;
extern fn g_slist_free(p_list: *SList) void;
