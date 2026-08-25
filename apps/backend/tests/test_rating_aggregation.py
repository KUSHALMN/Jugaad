import math


def calculate_aggregate_rating(ratings: list[float]) -> float:
    """
    Calculates aggregate worker rating formula:
    Aggregate Rating = Sum(Rating_i) / N, rounded to 2 decimal places.
    Returns 0.0 if ratings list is empty.
    """
    if not ratings:
        return 0.0
    return round(sum(ratings) / float(len(ratings)), 2)

def test_rating_aggregation_lifecycle():
    # Initial state: 0 jobs, 0 ratings
    ratings = []
    assert calculate_aggregate_rating(ratings) == 0.0

    # Job 1 rated 5 stars
    ratings.append(5.0)
    assert calculate_aggregate_rating(ratings) == 5.00

    # Job 2 rated 4 stars
    ratings.append(4.0)
    # (5 + 4) / 2 = 4.5
    assert calculate_aggregate_rating(ratings) == 4.50

    # Job 3 rated 3 stars
    ratings.append(3.0)
    # (5 + 4 + 3) / 3 = 4.0
    assert calculate_aggregate_rating(ratings) == 4.00

    # Job 4 rated 5 stars
    ratings.append(5.0)
    # (5 + 4 + 3 + 5) / 4 = 17 / 4 = 4.25
    assert calculate_aggregate_rating(ratings) == 4.25

if __name__ == "__main__":
    test_rating_aggregation_lifecycle()
    print("ALL RATING AGGREGATION TESTS PASSED SUCCESSFULLY!")
