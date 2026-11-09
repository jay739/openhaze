// Asks GitHub for the newest OpenHaze release. Notify-only: it never downloads
// or runs anything; the tray menu just opens the release page.
using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;

namespace OpenHaze
{
    internal sealed class ReleaseInfo
    {
        public readonly string Tag;       // e.g. "v0.3.0"
        public readonly string PageUrl;   // the release page on GitHub

        public ReleaseInfo(string tag, string pageUrl)
        {
            Tag = tag;
            PageUrl = pageUrl;
        }
    }

    // The ways an update check can fail. The base constructor is internal, so
    // these three are the whole set. Each message says what went wrong and what
    // to do about it.
    internal abstract class UpdateCheckException : Exception
    {
        internal UpdateCheckException(string message, Exception inner) : base(message, inner) { }

        protected static string Fallback()
        {
            return "or look for new versions at " + UpdateChecker.ReleasesPage;
        }
    }

    internal sealed class UpdateServerUnreachableException : UpdateCheckException
    {
        public UpdateServerUnreachableException(Exception inner)
            : base("OpenHaze couldn't reach GitHub to check for updates. Check your internet " +
                   "connection and try again, " + Fallback() + ".", inner) { }
    }

    internal sealed class UpdateServerErrorException : UpdateCheckException
    {
        public readonly int StatusCode;

        public UpdateServerErrorException(int statusCode, Exception inner)
            : base(MessageFor(statusCode), inner)
        {
            StatusCode = statusCode;
        }

        private static string MessageFor(int statusCode)
        {
            if (statusCode == 403 || statusCode == 429)
                return string.Format("GitHub is limiting update checks from your network right now " +
                                     "(HTTP {0}). Try again in an hour, {1}.", statusCode, Fallback());
            return string.Format("GitHub couldn't answer the update check (HTTP {0}). Try again later, {1}.",
                                 statusCode, Fallback());
        }
    }

    internal sealed class UpdateResponseUnreadableException : UpdateCheckException
    {
        public UpdateResponseUnreadableException(Exception inner)
            : base("GitHub's answer to the update check wasn't a release OpenHaze could read. " +
                   "Try again later, " + Fallback() + ".", inner) { }
    }

    internal static class UpdateChecker
    {
        public const string ReleasesPage = "https://github.com/jay739/openhaze/releases";
        private const string LatestReleaseApi = "https://api.github.com/repos/jay739/openhaze/releases/latest";

        [DataContract]
        private sealed class GitHubRelease
        {
            [DataMember(Name = "tag_name")] public string TagName { get; set; }
            [DataMember(Name = "html_url")] public string HtmlUrl { get; set; }
        }

        // Blocks for up to 15 seconds, so call it off the UI thread.
        public static ReleaseInfo FetchLatest(string currentVersion)
        {
            // The app runs on .NET Framework's older defaults; GitHub needs TLS 1.2.
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            var request = (HttpWebRequest)WebRequest.Create(LatestReleaseApi);
            request.UserAgent = "OpenHaze-Windows/" + currentVersion;   // GitHub rejects requests without one
            request.Accept = "application/vnd.github+json";
            request.Timeout = 15000;
            request.ReadWriteTimeout = 15000;
            try
            {
                using (var response = (HttpWebResponse)request.GetResponse())
                using (var body = response.GetResponseStream())
                    return ParseRelease(body);
            }
            catch (WebException e)
            {
                var http = e.Response as HttpWebResponse;
                if (http != null) throw new UpdateServerErrorException((int)http.StatusCode, e);
                throw new UpdateServerUnreachableException(e);
            }
            catch (IOException e)
            {
                throw new UpdateServerUnreachableException(e);
            }
        }

        public static ReleaseInfo ParseRelease(Stream json)
        {
            GitHubRelease release;
            try
            {
                release = (GitHubRelease)new DataContractJsonSerializer(typeof(GitHubRelease)).ReadObject(json);
            }
            catch (SerializationException e)
            {
                throw new UpdateResponseUnreadableException(e);
            }
            int[] numbers;
            string prerelease;
            if (release == null || !TryParse(release.TagName, out numbers, out prerelease))
                throw new UpdateResponseUnreadableException(null);

            // Only ever open a page in this repository, whatever the reply says.
            string page = release.HtmlUrl != null &&
                          release.HtmlUrl.StartsWith("https://github.com/jay739/openhaze/", StringComparison.Ordinal)
                ? release.HtmlUrl
                : ReleasesPage;
            return new ReleaseInfo(release.TagName, page);
        }

        // True when candidate (a tag like "v0.3.1") is a later release than current.
        // Numbers compare numerically, a release beats its own prerelease, and
        // build metadata after "+" is ignored. Anything unreadable is never newer.
        public static bool IsNewer(string candidate, string current)
        {
            int[] a, b;
            string aPre, bPre;
            if (!TryParse(candidate, out a, out aPre) || !TryParse(current, out b, out bPre)) return false;
            for (int i = 0; i < a.Length; i++)
                if (a[i] != b[i]) return a[i] > b[i];
            if (aPre == null) return bPre != null;
            if (bPre == null) return false;
            return string.CompareOrdinal(aPre, bPre) > 0;
        }

        // Local builds are stamped 0.0.0-dev; they skip the automatic check.
        public static bool IsDevelopmentBuild(string version)
        {
            int[] numbers;
            string prerelease;
            return TryParse(version, out numbers, out prerelease) &&
                   numbers[0] == 0 && numbers[1] == 0 && numbers[2] == 0 && numbers[3] == 0;
        }

        private static bool TryParse(string version, out int[] numbers, out string prerelease)
        {
            numbers = new int[4];
            prerelease = null;
            if (string.IsNullOrEmpty(version)) return false;
            string v = version.Trim();
            if (v.StartsWith("v", StringComparison.OrdinalIgnoreCase)) v = v.Substring(1);
            int plus = v.IndexOf('+');
            if (plus >= 0) v = v.Substring(0, plus);
            int dash = v.IndexOf('-');
            if (dash >= 0)
            {
                prerelease = v.Substring(dash + 1);
                v = v.Substring(0, dash);
            }
            string[] parts = v.Split('.');
            if (parts.Length > 4) return false;
            for (int i = 0; i < parts.Length; i++)
                if (!int.TryParse(parts[i], NumberStyles.None, CultureInfo.InvariantCulture, out numbers[i]))
                    return false;
            return true;
        }
    }
}
