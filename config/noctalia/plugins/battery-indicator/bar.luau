--!nonstrict

local POWER_SUPPLY_PATH = "/sys/class/power_supply"
local CHARGING_COLOR = "#166534"
local NORMAL_COLOR = "#22c55e"
local WARNING_COLOR = "#facc15"
local CRITICAL_COLOR = "#ef4444"

local batteryPath = nil

local function trim(value)
  return (value or ""):match("^%s*(.-)%s*$")
end

local function read(path)
  local value = noctalia.readFile(path)
  return value and trim(value) or nil
end

local function findSystemBattery()
  local entries = noctalia.listDir(POWER_SUPPLY_PATH)
  if not entries then
    return nil
  end

  table.sort(entries)
  for _, name in ipairs(entries) do
    if name:match("^BAT") then
      local path = POWER_SUPPLY_PATH .. "/" .. name
      if read(path .. "/type") == "Battery" then
        return path
      end
    end
  end

  return nil
end

local function colorFor(percent, status)
  if status == "Charging" or status == "Full" then
    return CHARGING_COLOR
  elseif percent <= 20 then
    return CRITICAL_COLOR
  elseif percent <= 35 then
    return WARNING_COLOR
  end
  return NORMAL_COLOR
end

local function glyphFor(percent, status)
  if status == "Charging" then
    return "battery-charging"
  elseif percent >= 85 then
    return "battery-4"
  elseif percent >= 55 then
    return "battery-3"
  elseif percent >= 30 then
    return "battery-2"
  elseif percent >= 10 then
    return "battery-1"
  end
  return "battery-0"
end

local function hideWidget()
  barWidget.render(ui.row())
  barWidget.clearTooltip()
end

local function renderBattery()
  if not batteryPath or not noctalia.fileExists(batteryPath .. "/present") then
    batteryPath = findSystemBattery()
  end

  if not batteryPath then
    hideWidget()
    return
  end

  local present = read(batteryPath .. "/present")
  local percent = tonumber(read(batteryPath .. "/capacity"))
  local status = read(batteryPath .. "/status") or "Unknown"

  if present ~= "1" or not percent then
    batteryPath = nil
    hideWidget()
    return
  end

  percent = math.max(0, math.min(100, math.floor(percent + 0.5)))
  local color = colorFor(percent, status)
  local container = barWidget.isVertical() and ui.column or ui.row

  barWidget.render(container({ gap = 4, align = "center" }, {
    ui.glyph({ name = glyphFor(percent, status), color = color }),
    ui.label({ text = tostring(percent) .. "%", color = color }),
  }))
  barWidget.setTooltip({
    { key = "Battery", value = tostring(percent) .. "%" },
    { key = "Status", value = status },
  })
end

function update()
  renderBattery()
end

noctalia.setUpdateInterval(10000)
renderBattery()
