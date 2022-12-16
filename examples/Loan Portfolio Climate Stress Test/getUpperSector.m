function var = getUpperSector(sector)
    var = extractBefore(sector,regexpPattern('\|(?!.*\|)'));
end