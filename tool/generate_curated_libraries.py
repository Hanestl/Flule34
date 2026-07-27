from __future__ import annotations

import argparse
import concurrent.futures
import io
import json
import math
import re
import subprocess
import unicodedata
import urllib.parse
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

import numpy as np
from bs4 import BeautifulSoup
from PIL import Image


SITE_ROOT = "https://rule34video.com"
SEARCH_BLOCK = "custom_list_videos_videos_list_search"
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".mkv", ".m4v", ".avi"}
AUTHOR_SPECS = (
    ("hydrafxx", "87", "作者：hydrafxx"),
    ("nagoonimation", "367", "作者：nagoonimation"),
    ("bamhor", "15702", "作者：bamhor"),
    ("JuicyNeko", "446", "作者：JuicyNeko"),
    ("Drills3D", "84", "作者：Drills3D"),
)
IGNORED_TOKENS = {
    "1080",
    "1080p",
    "2160",
    "2160p",
    "720",
    "720p",
    "480",
    "480p",
    "360",
    "360p",
    "2k",
    "4k",
    "8k",
    "30fps",
    "60fps",
    "fps",
    "mp4",
    "webm",
    "patreon",
    "sound",
    "audio",
    "wm",
    "nowm",
    "hydrafxx",
    "nagoonimation",
    "bamh3d",
    "bamhor",
    "juicyneko",
    "drills3d",
    "selfdrillingsms",
}
MANUAL_OVERRIDES = {
    (
        "nagoonimation",
        "12. 2B in the rain/2b_animation_4k.mp4",
    ): "3072997",
    (
        "nagoonimation",
        "12. 2B in the rain/2b_nude_4k.mp4",
    ): "3352835",
    (
        "nagoonimation",
        "13. Night Elf and Orc/Nelf_Orc_4k_.mp4",
    ): "3058399",
    (
        "nagoonimation",
        "13. Night Elf and Orc/Nelf_Orc_4k_Xray.mp4",
    ): "3058399",
    (
        "nagoonimation",
        "17. Lara Jungle Ruins/4k_Lara_Leotard.mp4",
    ): "3053319",
    (
        "nagoonimation",
        "18. Tifa Double Penetration/4k_Tifa_DP_Purple_Male_Audio.mp4",
    ): "3057631",
    (
        "nagoonimation",
        "2. Mercy/Mercy_Patreon.mp4",
    ): "3055408",
    (
        "nagoonimation",
        "22. Tifa and Cloud/4k_Tifa_Cloud_Full.mp4",
    ): "3056501",
    (
        "nagoonimation",
        "32. Marie Date/Male_Version_2160p_Marie No Music.mp4",
    ): "3067097",
    (
        "nagoonimation",
        "42. Yuffie/4K Yuffie 60Fps-1.mp4",
    ): "3122623",
    (
        "nagoonimation",
        "42. Yuffie/4K Yuffie Male Audio 60Fps-1.mp4",
    ): "3122760",
    (
        "nagoonimation",
        "8. Tifa in the Mako Reactor/Tifa_Mako_Nude_Patreon_4k.mp4",
    ): "3120612",
    (
        "nagoonimation",
        "8. Tifa in the Mako Reactor/Tifa_Mako_Patreon_4k.mp4",
    ): "3073094",
    (
        "Drills3D",
        "20230801(tifa yuffie) Double Up_1080p.mp4",
    ): "3278319",
    (
        "Drills3D",
        "20240518 (ellie) loyalty-pov-nude_1080p.mp4",
    ): "3655106",
    (
        "Drills3D",
        "20240518 (ellie) loyalty-pov_1080p.mp4",
    ): "3655109",
    (
        "JuicyNeko",
        "2020/2020.12 Tifa CowGirl Bra 4K.mp4",
    ): "3067502",
}
RECENT_VIDEO_LIMIT = 12
RECENT_EXCLUDED_WORDS = {
    "compilation",
    "collection",
    "hmv",
    "pmv",
    "tribute",
    "faphero",
    "fap hero",
    "mix",
}


@dataclass(frozen=True)
class LocalVideo:
    author: str
    relative_path: str
    title: str
    match_text: str
    duration_seconds: float
    size_bytes: int


@dataclass(frozen=True)
class SiteVideo:
    id: str
    slug: str
    title: str
    thumbnail_url: str | None
    preview_url: str | None
    duration_label: str | None
    duration_seconds: int | None
    published_label: str | None
    views: int | None
    rating: int | None
    rating_votes: int | None


@dataclass
class CandidateMatch:
    video: SiteVideo
    title_score: float
    duration_delta: float
    base_score: float
    image_distance: int | None = None
    max_height: int | None = None
    wilson_score: float = 0.0

    @property
    def image_score(self) -> float:
        if self.image_distance is None:
            return 0.0
        return max(0.0, min(1.0, (950 - self.image_distance) / 700))

    @property
    def identity_score(self) -> float:
        if self.image_distance is None:
            return self.base_score
        return 0.45 * self.title_score + 0.2 * _duration_score(
            self.duration_delta
        ) + 0.35 * self.image_score


class SiteClient:
    def __init__(self, *, workers: int) -> None:
        self.workers = workers
        self._image_hash_cache: dict[str, list[np.ndarray]] = {}
        self._details_cache: dict[str, tuple[int | None, int | None, int | None]] = {}

    def load_author_videos(self, model_id: str) -> list[SiteVideo]:
        first_page = self._load_search_page(model_id, 1)
        total = first_page[0]
        videos = {item.id: item for item in first_page[1]}
        page_count = max(1, math.ceil(total / 24))
        if page_count == 1:
            return list(videos.values())

        with concurrent.futures.ThreadPoolExecutor(
            max_workers=self.workers
        ) as executor:
            futures = {
                executor.submit(self._load_search_page, model_id, page): page
                for page in range(2, page_count + 1)
            }
            for future in concurrent.futures.as_completed(futures):
                page = futures[future]
                try:
                    _, items = future.result()
                except Exception as error:
                    raise RuntimeError(
                        f"艺术家 {model_id} 的第 {page} 页读取失败。"
                    ) from error
                for item in items:
                    videos[item.id] = item
        return list(videos.values())

    def image_hashes(self, video: SiteVideo) -> list[np.ndarray]:
        cached = self._image_hash_cache.get(video.id)
        if cached is not None:
            return cached
        hashes: list[np.ndarray] = []
        urls = _screenshot_urls(video.thumbnail_url)
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(5, len(urls) or 1)
        ) as executor:
            futures = [executor.submit(_download_image, url) for url in urls]
            for future in concurrent.futures.as_completed(futures):
                try:
                    image = future.result()
                except Exception:
                    continue
                hashes.append(_difference_hash(image))
        self._image_hash_cache[video.id] = hashes
        return hashes

    def load_quality(self, video: SiteVideo) -> tuple[int | None, int | None, int | None]:
        cached = self._details_cache.get(video.id)
        if cached is not None:
            return cached
        url = f"{SITE_ROOT}/popup-video/{video.id}/?popup_id=1"
        source = _request_text(url)
        labels = re.findall(
            r"video_(?:alt_)?url\d*_text:\s*'([^']+)'", source
        )
        heights = [_quality_height(label) for label in labels]
        max_height = max((height for height in heights if height), default=None)
        rating_match = re.search(r'class="voters count"[^>]*>(\d{1,3})%\s*\(([\d,]+)\)', source)
        rating = int(rating_match.group(1)) if rating_match else video.rating
        votes = (
            int(rating_match.group(2).replace(",", ""))
            if rating_match
            else video.rating_votes
        )
        result = (max_height, rating, votes)
        self._details_cache[video.id] = result
        return result

    def _load_search_page(self, model_id: str, page: int) -> tuple[int, list[SiteVideo]]:
        parameters = {
            "mode": "async",
            "function": "get_block",
            "block_id": SEARCH_BLOCK,
            "q": "",
            "from_videos": str(page),
            "from_albums": str(page),
            "sort_by": "rating",
            "model_ids": f"all,{model_id}",
        }
        url = f"{SITE_ROOT}/search/?{urllib.parse.urlencode(parameters)}"
        source = _request_text(url)
        return _parse_search_page(source)


def main() -> None:
    global _arguments_source_root
    parser = argparse.ArgumentParser(description="生成 Flule34 内置精选本地分类库。")
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument(
        "--authors",
        nargs="*",
        help="只处理指定作者，便于校准生成规则。",
    )
    arguments = parser.parse_args()
    _arguments_source_root = arguments.source_root

    client = SiteClient(workers=max(1, min(arguments.workers, 6)))
    libraries: list[dict[str, Any]] = []
    report_libraries: list[dict[str, Any]] = []
    selected_authors = {
        author.lower() for author in arguments.authors or ()
    }

    for author, model_id, library_name in AUTHOR_SPECS:
        if selected_authors and author.lower() not in selected_authors:
            continue
        print(f"正在读取 {author} 的网站候选……", flush=True)
        site_videos = client.load_author_videos(model_id)
        print(f"正在读取 {author} 的本地视频……", flush=True)
        local_videos = _load_local_videos(arguments.source_root, author)
        print(f"正在匹配 {author}……", flush=True)
        selected, report = _match_author(
            author=author,
            local_videos=local_videos,
            site_videos=site_videos,
            client=client,
        )
        libraries.append(
            {
                "key": f"author_{author.lower()}",
                "name": library_name,
                "videos": [_manifest_video(item) for item in selected],
            }
        )
        report_libraries.append(report)
        print(
            f"{author}: 本地 {len(local_videos)}，候选 {len(site_videos)}，"
            f"最终 {len(selected)}。",
            flush=True,
        )

    manifest = {"version": 1, "libraries": libraries}
    report = {
        "generatedAt": datetime.now(UTC).isoformat(),
        "sourceRoot": str(arguments.source_root),
        "manifestVersion": 1,
        "libraries": report_libraries,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.report.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    arguments.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _load_local_videos(root: Path, author: str) -> list[LocalVideo]:
    author_root = root / author
    if not author_root.is_dir():
        raise FileNotFoundError(f"没有找到作者目录：{author_root}")
    paths = sorted(
        path
        for path in author_root.rglob("*")
        if path.is_file() and path.suffix.lower() in VIDEO_EXTENSIONS
    )
    result: list[LocalVideo] = []
    for path in paths:
        duration = _probe_duration(path)
        relative = path.relative_to(author_root)
        context_parts = [path.stem]
        for part in relative.parts[:-1]:
            if not re.fullmatch(r"\d{6,8}", part) and not re.fullmatch(
                r"\d+[. _-]*", part
            ):
                context_parts.append(part)
        result.append(
            LocalVideo(
                author=author,
                relative_path=str(relative),
                title=path.stem,
                match_text=" ".join(context_parts),
                duration_seconds=duration,
                size_bytes=path.stat().st_size,
            )
        )
    return result


def _match_author(
    *,
    author: str,
    local_videos: list[LocalVideo],
    site_videos: list[SiteVideo],
    client: SiteClient,
) -> tuple[list[SiteVideo], dict[str, Any]]:
    selections: list[tuple[LocalVideo, CandidateMatch, str]] = []
    unresolved: list[dict[str, Any]] = []
    site_by_id = {video.id: video for video in site_videos}

    for index, local in enumerate(local_videos, start=1):
        override_id = MANUAL_OVERRIDES.get(
            (author, local.relative_path.replace("\\", "/"))
        )
        if override_id is not None:
            override_video = site_by_id.get(override_id)
            if override_video is None:
                raise RuntimeError(
                    f"人工确认的视频 {override_id} 不在 {author} 的候选集中。"
                )
            override_match = CandidateMatch(
                video=override_video,
                title_score=_title_score(local.match_text, override_video.title),
                duration_delta=abs(
                    local.duration_seconds - (override_video.duration_seconds or 0)
                ),
                base_score=1.0,
            )
            selections.append((local, override_match, "manual"))
            continue
        candidates = _candidate_matches(local, site_videos)
        if not candidates:
            unresolved.append({"local": asdict(local), "reason": "没有接近时长的候选"})
            continue

        best = candidates[0]
        confidence = _text_confidence(best)
        if confidence != "high":
            local_hashes = _local_frame_hashes(
                _local_path(local, author), local.duration_seconds
            )
            for candidate in _image_candidates(candidates):
                site_hashes = client.image_hashes(candidate.video)
                candidate.image_distance = _minimum_hash_distance(
                    local_hashes, site_hashes
                )
            candidates.sort(key=lambda item: item.identity_score, reverse=True)
            best = candidates[0]
            confidence = _resolved_confidence(best)

        if confidence == "unresolved":
            unresolved.append(
                {
                    "local": asdict(local),
                    "reason": "标题、时长和画面仍不足以可靠确认",
                    "candidates": [_candidate_report(item) for item in candidates[:5]],
                }
            )
            continue

        identity_floor = best.identity_score - 0.08
        alternatives = [
            item
            for item in candidates[:8]
            if item.identity_score >= identity_floor
            and item.duration_delta <= max(3.0, best.duration_delta + 1.0)
        ]
        if len(alternatives) > 1:
            with concurrent.futures.ThreadPoolExecutor(
                max_workers=min(4, len(alternatives))
            ) as executor:
                futures = {
                    executor.submit(client.load_quality, candidate.video): candidate
                    for candidate in alternatives
                }
                for future in concurrent.futures.as_completed(futures):
                    candidate = futures[future]
                    max_height, rating, votes = future.result()
                    candidate.max_height = max_height
                    candidate.wilson_score = _wilson_score(rating, votes)
        alternatives.sort(
            key=lambda item: (
                item.identity_score,
                item.max_height or 0,
                item.wilson_score,
                item.video.rating_votes or 0,
            ),
            reverse=True,
        )
        chosen = _choose_duplicate(alternatives, best)
        selections.append((local, chosen, confidence))
        if index % 5 == 0:
            print(f"  {author}: 已处理 {index}/{len(local_videos)}", flush=True)

    unique: dict[str, tuple[SiteVideo, list[dict[str, Any]]]] = {}
    for local, match, confidence in selections:
        evidence = {
            "local": asdict(local),
            "confidence": confidence,
            "match": _candidate_report(match),
        }
        current = unique.get(match.video.id)
        if current is None:
            unique[match.video.id] = (match.video, [evidence])
        else:
            current[1].append(evidence)

    recent_additions = _recent_high_quality_videos(
        site_videos=site_videos,
        excluded_ids=set(unique),
        client=client,
    )
    for match in recent_additions:
        unique[match.video.id] = (
            match.video,
            [
                {
                    "source": "recent_high_quality",
                    "confidence": "curated",
                    "match": _candidate_report(match),
                }
            ],
        )

    selected = [item[0] for item in unique.values()]
    selected.sort(key=lambda item: item.id)
    return selected, {
        "author": author,
        "localCount": len(local_videos),
        "siteCandidateCount": len(site_videos),
        "matchedLocalCount": len(selections),
        "selectedVideoCount": len(selected),
        "recentAdditionCount": len(recent_additions),
        "duplicateLocalCount": len(selections) - len(selected),
        "unresolvedCount": len(unresolved),
        "selected": [
            {"video": _manifest_video(video), "evidence": evidence}
            for video, evidence in unique.values()
        ],
        "unresolved": unresolved,
    }


def _recent_high_quality_videos(
    *,
    site_videos: list[SiteVideo],
    excluded_ids: set[str],
    client: SiteClient,
) -> list[CandidateMatch]:
    preliminary: list[CandidateMatch] = []
    for video in site_videos:
        if video.id in excluded_ids:
            continue
        age_days = _published_age_days(video.published_label)
        if age_days is None or age_days > 550:
            continue
        if video.rating is None or video.rating < 97:
            continue
        if video.rating_votes is None or video.rating_votes < 75:
            continue
        if (
            video.duration_seconds is None
            or video.duration_seconds < 8
            or video.duration_seconds > 600
        ):
            continue
        normalized_title = video.title.lower()
        if any(word in normalized_title for word in RECENT_EXCLUDED_WORDS):
            continue
        preliminary.append(
            CandidateMatch(
                video=video,
                title_score=1.0,
                duration_delta=0.0,
                base_score=1.0,
                wilson_score=_wilson_score(video.rating, video.rating_votes),
            )
        )

    preliminary.sort(
        key=lambda item: (
            item.wilson_score,
            item.video.rating_votes or 0,
            -(_published_age_days(item.video.published_label) or 0),
        ),
        reverse=True,
    )
    candidates = preliminary[:40]
    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(4, len(candidates) or 1)
    ) as executor:
        futures = {
            executor.submit(client.load_quality, item.video): item
            for item in candidates
        }
        for future in concurrent.futures.as_completed(futures):
            item = futures[future]
            max_height, rating, votes = future.result()
            item.max_height = max_height
            item.wilson_score = _wilson_score(rating, votes)

    candidates = [item for item in candidates if (item.max_height or 0) >= 1080]
    candidates.sort(
        key=lambda item: (
            item.max_height or 0,
            _frame_rate_hint(item.video.title),
            item.wilson_score,
            item.video.rating_votes or 0,
            -(_published_age_days(item.video.published_label) or 0),
        ),
        reverse=True,
    )
    return candidates[:RECENT_VIDEO_LIMIT]


def _candidate_matches(
    local: LocalVideo, site_videos: list[SiteVideo]
) -> list[CandidateMatch]:
    result: list[CandidateMatch] = []
    for video in site_videos:
        if video.duration_seconds is None:
            continue
        delta = abs(local.duration_seconds - video.duration_seconds)
        if delta > 10:
            continue
        title_score = max(
            _title_score(local.title, video.title),
            _title_score(local.match_text, video.title),
        )
        base_score = 0.72 * title_score + 0.28 * _duration_score(delta)
        result.append(
            CandidateMatch(
                video=video,
                title_score=title_score,
                duration_delta=delta,
                base_score=base_score,
            )
        )
    result.sort(key=lambda item: item.base_score, reverse=True)
    return result


def _image_candidates(candidates: list[CandidateMatch]) -> list[CandidateMatch]:
    selected: dict[str, CandidateMatch] = {}
    for candidate in candidates[:6]:
        selected[candidate.video.id] = candidate
    exact_duration = sorted(candidates, key=lambda item: item.duration_delta)
    for candidate in exact_duration[:12]:
        if candidate.duration_delta <= 1.25:
            selected[candidate.video.id] = candidate
    return list(selected.values())


def _choose_duplicate(
    alternatives: list[CandidateMatch], best_identity: CandidateMatch
) -> CandidateMatch:
    if not alternatives:
        return best_identity
    best_score = max(item.identity_score for item in alternatives)
    equivalent = [
        item for item in alternatives if item.identity_score >= best_score - 0.035
    ]
    equivalent.sort(
        key=lambda item: (
            item.max_height or 0,
            _frame_rate_hint(item.video.title),
            item.wilson_score,
            item.video.rating or 0,
            item.video.rating_votes or 0,
        ),
        reverse=True,
    )
    return equivalent[0]


def _text_confidence(candidate: CandidateMatch) -> str:
    if (
        candidate.duration_delta <= 1.3
        and candidate.title_score >= 0.52
        and candidate.base_score >= 0.62
    ):
        return "high"
    return "ambiguous"


def _resolved_confidence(candidate: CandidateMatch) -> str:
    distance = candidate.image_distance
    if distance is not None and distance <= 520 and candidate.duration_delta <= 5:
        return "image"
    if (
        candidate.duration_delta <= 2.5
        and candidate.title_score >= 0.42
        and candidate.identity_score >= 0.55
    ):
        return "medium"
    return "unresolved"


def _parse_search_page(source: str) -> tuple[int, list[SiteVideo]]:
    document = BeautifulSoup(source, "html.parser")
    total_element = document.select_one(".total_results")
    total = (
        int(re.sub(r"\D", "", total_element.get_text()))
        if total_element is not None
        else 0
    )
    result: list[SiteVideo] = []
    for card in document.select("div.item.thumb"):
        link = card.select_one('a.th[href*="/video/"]')
        if link is None:
            continue
        match = re.search(r"/video/(\d+)/([^/]+)/?", link.get("href", ""))
        if match is None:
            continue
        title_element = card.select_one(".thumb_title")
        title = (
            title_element.get_text(" ", strip=True)
            if title_element is not None
            else link.get("title", "")
        )
        duration_element = card.select_one(".time")
        duration_label = (
            duration_element.get_text(" ", strip=True)
            if duration_element is not None
            else None
        )
        rating_element = card.select_one(".thumb_info .rating")
        rating_text = (
            rating_element.get_text(" ", strip=True)
            if rating_element is not None
            else ""
        )
        rating_match = re.search(
            r"(\d{1,3})\s*%\s*\(([\d,.KMB]+)\)", rating_text, re.IGNORECASE
        )
        image = card.select_one("img.thumb")
        thumbnail_url = None
        if image is not None:
            thumbnail_url = (
                image.get("data-webp")
                or image.get("data-original")
                or image.get("src")
            )
        preview = card.select_one(".wrap_image[data-preview]")
        published = card.select_one(".thumb_info .added")
        views = card.select_one(".thumb_info .views")
        result.append(
            SiteVideo(
                id=match.group(1),
                slug=match.group(2),
                title=title,
                thumbnail_url=thumbnail_url,
                preview_url=preview.get("data-preview") if preview is not None else None,
                duration_label=duration_label,
                duration_seconds=_duration_seconds(duration_label),
                published_label=(
                    published.get_text(" ", strip=True) if published is not None else None
                ),
                views=_compact_number(
                    views.get_text(" ", strip=True) if views is not None else None
                ),
                rating=int(rating_match.group(1)) if rating_match else None,
                rating_votes=(
                    _compact_number(rating_match.group(2)) if rating_match else None
                ),
            )
        )
    return total, result


def _request_text(url: str) -> str:
    last_error: Exception | None = None
    for _ in range(2):
        try:
            completed = subprocess.run(
                [
                    "curl.exe",
                    "-L",
                    "-sS",
                    "--fail",
                    "--max-time",
                    "20",
                    "-A",
                    "Mozilla/5.0",
                    url,
                ],
                capture_output=True,
            )
            if completed.returncode != 0:
                raise RuntimeError(completed.stderr.decode("utf-8", errors="replace"))
            return completed.stdout.decode("utf-8", errors="replace")
        except Exception as error:
            last_error = error
    raise RuntimeError(f"网络请求失败：{url}") from last_error


def _download_image(url: str) -> Image.Image:
    completed = subprocess.run(
        [
            "curl.exe",
            "-L",
            "-sS",
            "--fail",
            "--max-time",
            "10",
            "-A",
            "Mozilla/5.0",
            url,
        ],
        capture_output=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.decode("utf-8", errors="replace"))
    return Image.open(io.BytesIO(completed.stdout)).convert("L").resize((65, 36))


def _screenshot_urls(thumbnail_url: str | None) -> list[str]:
    if not thumbnail_url:
        return []
    match = re.match(r"(.*/)(\d+)\.jpg(?:\?.*)?$", thumbnail_url)
    if match is None:
        return [thumbnail_url]
    prefix = match.group(1)
    preferred = int(match.group(2))
    indexes = [preferred, *[index for index in (1, 3, 5, 7, 9) if index != preferred]]
    return [f"{prefix}{index}.jpg" for index in indexes]


def _local_path(local: LocalVideo, author: str) -> Path:
    return _arguments_source_root / author / local.relative_path


def _local_frame_hashes(path: Path, duration: float) -> list[np.ndarray]:
    frame_size = 65 * 36
    result: list[np.ndarray] = []
    for fraction in (0.05, 0.16, 0.27, 0.38, 0.49, 0.60, 0.71, 0.82, 0.93):
        command = [
            "ffmpeg",
            "-v",
            "error",
            "-ss",
            f"{duration * fraction:.3f}",
            "-i",
            str(path),
            "-frames:v",
            "1",
            "-vf",
            "scale=65:36:force_original_aspect_ratio=increase,crop=65:36",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "gray",
            "-",
        ]
        completed = subprocess.run(command, capture_output=True)
        if completed.returncode != 0 or len(completed.stdout) < frame_size:
            continue
        frame = np.frombuffer(completed.stdout[:frame_size], dtype=np.uint8).reshape(
            (36, 65)
        )
        result.append(_difference_hash(frame))
    if not result:
        raise RuntimeError(f"无法从本地视频抽帧：{path}")
    return result


def _difference_hash(image: Image.Image | np.ndarray) -> np.ndarray:
    values = np.asarray(image, dtype=np.uint8)
    return (values[:, 1:] > values[:, :-1]).reshape(-1)


def _minimum_hash_distance(
    local_hashes: list[np.ndarray], site_hashes: list[np.ndarray]
) -> int | None:
    if not local_hashes or not site_hashes:
        return None
    return min(
        int(np.count_nonzero(local_hash != site_hash))
        for local_hash in local_hashes
        for site_hash in site_hashes
    )


def _probe_duration(path: Path) -> float:
    completed = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"无法读取视频时长：{path}")
    return float(completed.stdout.strip())


def _normalize_title(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    value = re.sub(r"([a-z])([A-Z])", r"\1 \2", value)
    value = value.lower().replace("d.va", "dva").replace("d va", "dva")
    value = re.sub(r"^\s*20\d{2}[. _-]*\d{0,2}[. _-]*\d{0,2}", " ", value)
    value = re.sub(r"[^a-z0-9]+", " ", value)
    tokens = [token for token in value.split() if token not in IGNORED_TOKENS]
    return " ".join(tokens)


def _title_score(left: str, right: str) -> float:
    left = _normalize_title(left)
    right = _normalize_title(right)
    if not left or not right:
        return 0.0
    left_tokens = set(left.split())
    right_tokens = set(right.split())
    union = left_tokens | right_tokens
    intersection = left_tokens & right_tokens
    jaccard = len(intersection) / len(union) if union else 0.0
    sequence = SequenceMatcher(None, left, right).ratio()
    containment = 1.0 if left in right or right in left else 0.0
    return max(sequence, 0.65 * jaccard + 0.35 * containment)


def _duration_score(delta: float) -> float:
    return max(0.0, 1.0 - delta / 8.0)


def _duration_seconds(label: str | None) -> int | None:
    if not label:
        return None
    try:
        parts = [int(part) for part in label.split(":")]
    except ValueError:
        return None
    if len(parts) == 2:
        return parts[0] * 60 + parts[1]
    if len(parts) == 3:
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    return None


def _compact_number(value: str | None) -> int | None:
    if not value:
        return None
    normalized = value.strip().replace(",", "").upper()
    multiplier = 1
    if normalized.endswith("K"):
        multiplier = 1000
        normalized = normalized[:-1]
    elif normalized.endswith("M"):
        multiplier = 1_000_000
        normalized = normalized[:-1]
    elif normalized.endswith("B"):
        multiplier = 1_000_000_000
        normalized = normalized[:-1]
    try:
        return int(float(normalized) * multiplier)
    except ValueError:
        return None


def _quality_height(label: str) -> int | None:
    normalized = label.strip().lower()
    if normalized == "4k":
        return 2160
    match = re.search(r"(\d{3,4})p?", normalized)
    return int(match.group(1)) if match else None


def _published_age_days(label: str | None) -> int | None:
    if not label:
        return None
    normalized = label.strip().lower()
    if normalized in {"today", "just now"}:
        return 0
    if normalized == "yesterday":
        return 1
    match = re.search(
        r"(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago",
        normalized,
    )
    if match is None:
        return None
    value = int(match.group(1))
    unit = match.group(2)
    multipliers = {
        "second": 0,
        "minute": 0,
        "hour": 0,
        "day": 1,
        "week": 7,
        "month": 30,
        "year": 365,
    }
    return value * multipliers[unit]


def _frame_rate_hint(title: str) -> int:
    normalized = title.lower().replace(" ", "")
    match = re.search(r"(\d{2,3})fps", normalized)
    return int(match.group(1)) if match else 0


def _wilson_score(rating: int | None, votes: int | None) -> float:
    if rating is None or votes is None or votes <= 0:
        return 0.0
    successes = votes * max(0.0, min(1.0, rating / 100))
    proportion = successes / votes
    z = 1.96
    denominator = 1 + z * z / votes
    centre = proportion + z * z / (2 * votes)
    margin = z * math.sqrt(
        (proportion * (1 - proportion) + z * z / (4 * votes)) / votes
    )
    return (centre - margin) / denominator


def _manifest_video(video: SiteVideo) -> dict[str, Any]:
    return {
        "id": video.id,
        "title": video.title,
        "slug": video.slug,
        "thumbnailUrl": video.thumbnail_url,
        "duration": video.duration_label,
        "publishedLabel": video.published_label,
        "views": video.views,
        "rating": video.rating,
        "ratingVotes": video.rating_votes,
    }


def _candidate_report(candidate: CandidateMatch) -> dict[str, Any]:
    return {
        "video": _manifest_video(candidate.video),
        "titleScore": round(candidate.title_score, 4),
        "durationDelta": round(candidate.duration_delta, 4),
        "baseScore": round(candidate.base_score, 4),
        "imageDistance": candidate.image_distance,
        "identityScore": round(candidate.identity_score, 4),
        "maxHeight": candidate.max_height,
        "wilsonScore": round(candidate.wilson_score, 6),
    }


_arguments_source_root: Path


if __name__ == "__main__":
    main()
