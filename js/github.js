var CACHE_PREFIX = 'teleprompter_';

export async function listScripts(owner, repo) {
    var cacheKey = CACHE_PREFIX + 'list_' + owner + '_' + repo;
    var cached = sessionStorage.getItem(cacheKey);
    if (cached) return JSON.parse(cached);

    var url = 'https://api.github.com/repos/' + encodeURIComponent(owner) + '/' + encodeURIComponent(repo) + '/contents/scripts';
    var res = await fetch(url);

    if (res.status === 403) {
        throw new Error('GitHub API rate limit reached. Try again in a few minutes.');
    }
    if (res.status === 404) {
        throw new Error('Repository or scripts/ folder not found. Make sure the repo is public and has a scripts/ directory.');
    }
    if (!res.ok) {
        throw new Error('GitHub API error: ' + res.status);
    }

    var files = await res.json();
    var scripts = files
        .filter(function(f) { return f.name.endsWith('.md'); })
        .map(function(f) {
            return {
                filename: f.name,
                name: f.name.replace(/\.md$/, '').replace(/[-_]/g, ' ').replace(/\b\w/g, function(c) { return c.toUpperCase(); }),
                downloadUrl: f.download_url
            };
        });

    sessionStorage.setItem(cacheKey, JSON.stringify(scripts));
    return scripts;
}

export async function fetchScript(owner, repo, filename) {
    var cacheKey = CACHE_PREFIX + 'script_' + owner + '_' + repo + '_' + filename;
    var cached = sessionStorage.getItem(cacheKey);
    if (cached) return cached;

    var url = 'https://raw.githubusercontent.com/' + encodeURIComponent(owner) + '/' + encodeURIComponent(repo) + '/main/scripts/' + encodeURIComponent(filename);
    var res = await fetch(url);

    if (!res.ok) {
        throw new Error('Failed to fetch script: ' + res.status);
    }

    var text = await res.text();
    sessionStorage.setItem(cacheKey, text);
    return text;
}

export function wordCount(text) {
    return text.split(/\s+/).filter(function(w) { return w.length > 0; }).length;
}

export function estimateReadTime(words, wpm) {
    var rate = wpm || 150;
    var minutes = Math.ceil(words / rate);
    return '~' + minutes + ' min read';
}
