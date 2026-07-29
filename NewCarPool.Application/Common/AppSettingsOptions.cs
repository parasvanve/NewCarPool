using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NewCarPool.Application.Common;

public sealed class AppSettingsOptions
{
    public const string SectionName = "Application";

    public string BaseUrl { get; set; } = string.Empty;
}
