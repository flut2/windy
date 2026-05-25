const std = @import("std");
const builtin = @import("builtin");

const options = @import("options");

pub const GtkError = error{
    /// GTK could not be initialized.
    Initialize,
} || std.mem.Allocator.Error;

pub const ZenityError =
    std.process.RunError ||
    std.fmt.ParseIntError ||
    std.Io.Writer.Error ||
    error{ ResultFormat, ExitCode };

pub const WinError = error{
    /// The dialog instance could not be initialized.
    Instance,
    /// Could not parse results.
    Result,
    /// Setting attributes, such as multi-select, failed.
    Attribute,
    /// Setting a filter failed. Note that this doesn't include conversion errors,
    /// those are either `OutOfMemory` or `InvalidWtf8`.
    Filter,
    /// Setting the title failed. Note that this doesn't include conversion errors,
    /// those are either `OutOfMemory` or `InvalidWtf8`.
    Title,
    /// Setting the default path failed. Note that this doesn't include conversion errors,
    /// those are either `OutOfMemory` or `InvalidWtf8`.
    DefaultPath,
    /// Could not present the dialog.
    Show,

    /// A WTF8 conversion function from `std.unicode` failed.
    InvalidWtf8,
} || std.mem.Allocator.Error;

/// This is an union of all the platform-specific errors,
/// but you can discard certain platforms' errors if you do not support them,
/// each platform is guaranteed to return errors from their own error set.
pub const Error = GtkError || ZenityError || WinError;
