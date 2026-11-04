from app.models import Site
from app.services.site_translation import site_source_hash


def test_site_source_hash_is_stable_and_changes_with_vietnamese_source() -> None:
    source = Site(name="Site", description="Source description", address="Hanoi")
    same = Site(name="Site", description="Source description", address="Hanoi")
    changed = Site(name="Site", description="Updated description", address="Hanoi")

    assert site_source_hash(source) == site_source_hash(same)
    assert site_source_hash(source) != site_source_hash(changed)
