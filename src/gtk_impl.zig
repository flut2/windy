const std = @import("std");

const zd = @import("zd.zig");

const FileChooserAction = enum(c_int) {
    open = 0,
    save = 1,
    select_folder = 2,
    create_folder = 3,
    _,
};

const ResponseType = enum(c_int) {
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

pub const SList = extern struct {
    f_data: ?*anyopaque,
    f_next: ?*SList,
};

fn gtkOpenDialog(title: [:0]const u8, dialog_type: zd.DialogType) *anyopaque {
    return gtk_file_chooser_dialog_new(
        title,
        null,
        if (dialog_type == .directory) .select_folder else .open,
        "_Cancel",
        @intFromEnum(ResponseType.cancel),
        "_Open",
        @intFromEnum(ResponseType.accept),
        @as(usize, 0),
    );
}

fn appendFileFilters(dialog: *anyopaque, filters: []const zd.SentinelFilter) void {
    for (filters) |f| {
        const filter = gtk_file_filter_new();
        gtk_file_filter_set_name(filter, f.name);
        if (f.exts) |exts| for (exts) |ext|
            gtk_file_filter_add_pattern(filter, ext);
        gtk_file_chooser_add_filter(dialog, filter);
    }
}

fn wait() void {
    while (gtk_events_pending() != 0)
        _ = gtk_main_iteration();
}

pub fn openDialog(
    comptime multiple_selection: bool,
    child_allocator: std.mem.Allocator,
    dialog_type: zd.DialogType,
    filters: []const zd.SentinelFilter,
    title: [:0]const u8,
    default_path: ?[:0]const u8,
) !if (multiple_selection) []const []const u8 else []const u8 {
    if (gtk_init_check(null, null) == 0) return error.InitializationFailed;

    const dialog = gtkOpenDialog(title, dialog_type);
    defer {
        wait();
        gtk_widget_destroy(dialog);
        wait();
    }

    if (multiple_selection) gtk_file_chooser_set_select_multiple(dialog, 1);
    if (default_path) |path| _ = gtk_file_chooser_set_current_folder(dialog, path);
    appendFileFilters(dialog, filters);

    if (gtk_dialog_run(dialog) != @intFromEnum(ResponseType.accept))
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
    child_allocator: std.mem.Allocator,
    filters: []const zd.SentinelFilter,
    title: [:0]const u8,
    default_path: ?[:0]const u8,
) ![]const u8 {
    if (gtk_init_check(null, null) == 0) return error.InitializationFailed;

    const dialog = gtk_file_chooser_dialog_new(
        title,
        null,
        .save,
        "_Cancel",
        @intFromEnum(ResponseType.cancel),
        "_Open",
        @intFromEnum(ResponseType.accept),
        @as(usize, 0),
    );
    defer {
        wait();
        gtk_widget_destroy(dialog);
        wait();
    }

    if (default_path) |path| _ = gtk_file_chooser_set_current_folder(dialog, path);
    appendFileFilters(dialog, filters);

    if (gtk_dialog_run(dialog) != @intFromEnum(ResponseType.accept))
        return &.{};

    const path = gtk_file_chooser_get_filename(dialog) orelse return &.{};
    defer g_free(path);
    return child_allocator.dupe(u8, std.mem.span(path));
}

extern fn gtk_init_check(p_argc: ?*c_int, p_argv: ?*[*][*:0]u8) c_int;
extern fn gtk_events_pending() c_int;
extern fn gtk_main_iteration() c_int;

extern fn gtk_file_filter_new() *anyopaque;
extern fn gtk_file_filter_add_pattern(p_filter: *anyopaque, p_pattern: [*:0]const u8) void;
extern fn gtk_file_filter_set_name(p_filter: *anyopaque, p_name: ?[*:0]const u8) void;

extern fn gtk_file_chooser_dialog_new(
    p_title: ?[*:0]const u8,
    p_parent: ?*anyopaque,
    p_action: FileChooserAction,
    p_first_button_text: ?[*:0]const u8,
    ...,
) *anyopaque;
extern fn gtk_file_chooser_set_select_multiple(p_chooser: *anyopaque, p_select_multiple: c_int) void;
extern fn gtk_file_chooser_add_filter(p_chooser: *anyopaque, p_filter: *anyopaque) void;
extern fn gtk_file_chooser_set_current_folder(p_chooser: *anyopaque, p_filename: [*:0]const u8) c_int;
extern fn gtk_file_chooser_get_filename(p_chooser: *anyopaque) ?[*:0]u8;
extern fn gtk_file_chooser_get_filenames(p_chooser: *anyopaque) *SList;

extern fn gtk_dialog_run(p_dialog: *anyopaque) c_int;
extern fn gtk_widget_destroy(p_widget: *anyopaque) void;

extern fn g_free(p_mem: ?*anyopaque) void;
extern fn g_slist_free(p_list: *SList) void;
