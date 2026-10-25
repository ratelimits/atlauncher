.pragma library
/* TMDB: popular shows on each Dock streaming app (3 per app). Backdrops are 1920x1080 on screen: TMDB has no such
   size (w1280 is the largest below "original"), so the original is fetched and decoded straight to 1920x1080
   (SceneLayer's sourceSize); row cards use w1280; title logos the original PNG, decoded at display size. The only network requests are to
   api.themoviedb.org and image.tmdb.org. */

var API = 'https://api.themoviedb.org/3', IMG = 'https://image.tmdb.org/t/p/';
var TTL = 12 * 3600 * 1000, ITEMS = 3;

/* Some title logos are SVG (Silo's), which Qt here can't draw, so the show's name was shown instead. TMDB serves
   the same logo as a PNG at the same path with a .png extension (the original, decoded at display size). */
function pngLogo(url) { return /\.svg$/i.test(url) ? url.slice(0, -4) + '.png' : url; }

function getJSON(url, done) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        var data = null;
        try { if (xhr.status === 200) data = JSON.parse(xhr.responseText); } catch (e) {}
        done(data);
    };
    xhr.open('GET', url);
    xhr.send();
}

// apps: [{ id, tmdb, style }]. done(items) with items: appId -> [{ name, overview, backdrop, card, logo }], or null.
function refresh(key, apps, done) {
    var since = new Date(Date.now() - 4 * 365 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    var pending = 0, fresh = {}, any = false;
    apps.forEach(function (app) {
        if (!app.tmdb) return;
        pending++;
        getJSON(API + '/discover/tv?api_key=' + key + '&watch_region=US&with_watch_providers=' + app.tmdb +
            '&sort_by=popularity.desc&first_air_date.gte=' + since + '&vote_count.gte=40&with_original_language=en&include_adult=false',
            function (data) {
                var shows = ((data && data.results) || []).filter(function (s) { return s.backdrop_path; }).slice(0, ITEMS);
                var items = shows.map(function (s) {
                    return { name: s.name, overview: s.overview || '', backdrop: IMG + 'original' + s.backdrop_path,
                             card: IMG + 'w1280' + s.backdrop_path, logo: '' };
                });
                var logosLeft = app.style === 'carousel' ? shows.length : 0;
                if (!logosLeft) return finish();
                shows.forEach(function (s, i) {
                    getJSON(API + '/tv/' + s.id + '/images?api_key=' + key + '&include_image_language=en,null', function (img) {
                        var logo = img && img.logos && img.logos.filter(function (l) { return l.iso_639_1 === 'en' || !l.iso_639_1; })[0];
                        if (logo) items[i].logo = pngLogo(IMG + 'original' + logo.file_path);
                        if (--logosLeft === 0) finish();
                    });
                });
                function finish() {
                    if (items.length) { fresh[app.id] = items; any = true; }
                    if (--pending === 0) done(any ? fresh : null);
                }
            });
    });
    if (!pending) done(null);
}
