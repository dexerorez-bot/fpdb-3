#!/usr/bin/env python3
"""A GGPoker tournament header may put the ante in brackets after the blinds.

"Level5(100/200(20))" made re_game_info fail, so every hand of such a file
raised FpdbParseError. The ante itself is read from the "posts the ante" lines.
"""

from __future__ import annotations

import pytest

from fpdb_3_legacy.GGPokerToFpdb import GGPoker

HEADER = (
    "Poker Hand #TM6622828917: Tournament #323740070, *3 Step to *215 Zodiac "
    "Mystery Bounty King, *3M GTD Hold'em No Limit - Level5(100/200(20)) - "
    "2026/11/04 13:22:10\n"
)


def test_an_ante_in_brackets_after_the_blinds_is_accepted():
    parser = GGPoker.__new__(GGPoker)

    info = parser.determineGameType(HEADER)

    assert info["sb"] == "100"
    assert info["bb"] == "200"
    assert info["type"] == "tour"


@pytest.mark.parametrize(
    "header",
    [
        "Poker Hand #TM1: Tournament #5, Daily Hold'em No Limit - Level2(60/120) - 2020/06/02 19:17:33\n",
        "Poker Hand #TM1: Tournament #5, Daily Hold'em No Limit - Level2 (60/120) - 2020/06/02 19:17:33\n",
    ],
)
def test_headers_without_an_ante_still_match(header):
    assert GGPoker.re_game_info.search(header) is not None
