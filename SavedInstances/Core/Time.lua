local SI, L = unpack(select(2, ...))

do
  local GTToffset = time() - GetTime()
  function SI:GetTimeToTime(val)
    if not val then return end
    return val + GTToffset
  end
end

-- returns how many hours the server time is ahead of local time
-- convert local time -> server time: add this value
-- convert server time -> local time: subtract this value
function SI:GetServerOffset()
  local serverDate = C_DateAndTime.GetCurrentCalendarTime() -- 1-based starts on Sun
  local serverWeekday, serverMinute, serverHour = serverDate.weekday - 1, serverDate.minute, serverDate.hour
  -- #211: date('%w') is 0-based starts on Sun
  local localWeekday = tonumber(date('%w'))
  local localHour, localMinute = tonumber(date('%H')), tonumber(date('%M'))
  if serverWeekday == (localWeekday + 1) % 7 then -- server is a day ahead
    serverHour = serverHour + 24
  elseif localWeekday == (serverWeekday + 1) % 7 then -- local is a day ahead
    localHour = localHour + 24
  end
  local serverT = serverHour + serverMinute / 60
  local localT = localHour + localMinute / 60
  local offset = floor((serverT - localT) * 2 + 0.5) / 2
  return offset
end

function SI:GetNextDailyResetTime()
  local resetTime = GetQuestResetTime()
  if (
    not resetTime or resetTime <= 0 or -- ticket 43: can fail during startup
    -- also right after a daylight savings rollover, when it returns negative values >.<
    resetTime > 24 * 60 * 60 + 30 -- can also be wrong near reset in an instance
  ) then
    return
  end

  return time() + resetTime
end

SI.GetNextDailySkillResetTime = SI.GetNextDailyResetTime

function SI:GetNextWeeklyResetTime()
  return time() + C_DateAndTime.GetSecondsUntilWeeklyReset()
end

do
  local darkmoonEnd = {hour=23, min=59}
  function SI:GetNextDarkmoonResetTime()
    -- Darkmoon faire runs from first Sunday of each month to following Saturday
    -- this function returns an approximate time after the end of the current month's faire
    local monthInfo = C_Calendar.GetMonthInfo()
    local firstWeekday = monthInfo.firstWeekday
    local firstSunday = ((firstWeekday == 1) and 1) or (9 - firstWeekday)
    darkmoonEnd.year = monthInfo.year
    darkmoonEnd.month = monthInfo.month
    darkmoonEnd.day = firstSunday + 7 -- 1 days of "slop"
    -- Unfortunately, DMF boundary ignores daylight savings, and the time of day varies across regions
    -- Report a reset well past end to make sure we don't drop quests early
    return time(darkmoonEnd) - SI:GetServerOffset() * 3600
  end
end