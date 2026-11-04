import hashlib
import json

from app.models import Site


def site_source_values(site: Site) -> dict[str, str | None]:
    return {
        "name": site.name,
        "description": site.description,
        "address": site.address,
    }


def site_source_hash(site: Site) -> str:
    canonical = json.dumps(
        site_source_values(site),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
