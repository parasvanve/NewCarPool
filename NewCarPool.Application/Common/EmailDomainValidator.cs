using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NewCarPool.Application.Common
{
    public static class EmailDomainValidator
    {
        private static readonly HashSet<string> AllowedDomains =
            new(StringComparer.OrdinalIgnoreCase)
            {
            "yopmail.com",
            "gmail.com",
            "tcs.com",
            "capgemini.com",
            "kallwik.in"
            };

        public static bool IsAllowed(string email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return false;

            var parts = email.Split('@');

            if (parts.Length != 2)
                return false;

            return AllowedDomains.Contains(parts[1]);
        }
    }
}
