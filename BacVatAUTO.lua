local comp = require("component")
local event = require("event")
local computer = require("computer")
local side = require("sides")
local os = require("os")
local gt = comp.gt_machine
local trans = comp.transposer
local term = require("term")
local io = require("io")
local keyboard = require("keyboard")
term.clear()

local function handleKey(char)
    -- placeholder, assigned later
end

function interruptableSleep(time) -- Альтернатива os.sleep, которая нормально работает с ctrl+c, а не только ctrl+alt+c
    local deadline = computer.uptime() + (time or 0)
    while true do
        local remaining = deadline - computer.uptime()
        if remaining <= 0 then
            return true
        end
        local e = {event.pull(math.min(0.1, remaining))}
        if #e > 0 then
            if e[1] == "interrupted" then
                return false
            end
            if e[1] == "key_down" then
                handleKey(e[3])
            end
        end
    end
end

local transLib = {}
local outputHatchLib = {}
local radioHatchLib = {}
local scanning = true
local outputHatches = 0
local tankSide = side.down
while scanning == true do
    for deliver, _ in pairs(comp.list("trans")) do
        table.insert(transLib, comp.proxy(deliver))
    end
    for key, _ in pairs(comp.list("gt_machine")) do
        local machine = comp.proxy(key)
        if string.find(machine.getName(), "radio", 1, true) then
            local x, y, z = machine.getCoordinates()
            rad = {machine, {x = x, y = y, z = z}}
            table.insert(radioHatchLib, rad)
        elseif string.find(machine.getName(), "hatch.output", 1, true) then
            local x, y, z = machine.getCoordinates()
            out = {machine, {x = x, y = y, z = z}}
            table.insert(outputHatchLib, out)
            outputHatches = outputHatches + 1
        end
    end
    scanning = false
end
local HatchesGroup = {}
local printError
local radioForcedOff = {}

local function isTransposerUsedForFluid(fluidType, transposer)
    for _, group in ipairs(HatchesGroup) do
        if group[1] == fluidType and group[5] == transposer then
            return true
        end
    end
    return false
end

local function listTransposersWithFluid(fluidType)
    local list = {}
    local foundAny = false
    for _, tr in pairs(transLib) do
        local fluidInTank = tr.getFluidInTank(tankSide)
        if fluidInTank then
            for _, info in pairs(fluidInTank) do
                if info.label == fluidType then
                    foundAny = true
                    if not isTransposerUsedForFluid(fluidType, tr) then
                        table.insert(list, {tr = tr, amount = info.amount or 0, capacity = info.capacity or 0})
                    end
                    break
                end
            end
        end
    end
    return list, foundAny
end

local function chooseTransposerForFluid(fluidType)
    local list, foundAny = listTransposersWithFluid(fluidType)
    if #list == 0 then
        if foundAny then
            return nil, "All transposers with fluid '" .. fluidType .. "' are already used"
        end
        return nil, "Transposer with fluid '" .. fluidType .. "' not found"
    end
    if #list == 1 then
        return list[1].tr, nil
    end
    while true do
        print("Select transposer index for '" .. fluidType .. "':")
        for i, item in ipairs(list) do
            local addr = item.tr.address or tostring(item.tr)
            print(string.format("  %d) %s | %d/%d", i, tostring(addr), item.amount, item.capacity))
        end
        local idx = tonumber(io.read())
        if idx and list[idx] then
            return list[idx].tr, nil
        end
        if printError then
            printError("Invalid transposer index")
        else
            print("Invalid transposer index")
        end
    end
end

local function listRadiosForOutput(outRawCoord)
    local list = {}
    for _, radio in pairs(radioHatchLib) do
        local radioMachine = radio[1]
        local radRawCoord = radio[2]
        if outRawCoord.x == radRawCoord.x and outRawCoord.z == radRawCoord.z then
            table.insert(list, {machine = radioMachine, coord = radRawCoord})
        end
    end
    return list
end

local function chooseRadioForOutput(outRawCoord)
    local list = listRadiosForOutput(outRawCoord)
    if #list == 0 then
        return nil, nil, "Radio hatch not found for output"
    end
    if #list == 1 then
        return list[1].machine, list[1].coord, nil
    end
    while true do
        print("Select radio hatch index:")
        for i, item in ipairs(list) do
            local addr = item.machine and (item.machine.address or tostring(item.machine)) or "?"
            print(string.format("  %d) %s", i, tostring(addr)))
        end
        local idx = tonumber(io.read())
        if idx and list[idx] then
            return list[idx].machine, list[idx].coord, nil
        end
        if printError then
            printError("Invalid radio hatch index")
        else
            print("Invalid radio hatch index")
        end
    end
end

local function buildGroup(fluidType, optFluidRate)
    local neededHatch = nil
    local outRawCoord = nil

    for _, hatch in pairs(outputHatchLib) do
        local thatHatch = hatch
        local coord = hatch[2]
        if string.find(thatHatch[1].getSensorInformation()[2], fluidType, 1, true) then
            neededHatch = thatHatch
            outRawCoord = coord
            break
        end
    end
    if not outRawCoord then
        return nil, "Output hatch for fluid '" .. fluidType .. "' not found"
    end

    local thatsHatch, err = chooseTransposerForFluid(fluidType)
    if not thatsHatch then
        return nil, err
    end

    local outputInterfaceSide = nil
    for _, s in ipairs({side.up, side.north, side.south, side.west, side.east}) do
        if thatsHatch.getInventoryName(s) == "tile.fluid_interface" then
            outputInterfaceSide = s
            break
        end
    end
    if not outputInterfaceSide then
        return nil, "Fluid interface not found around transposer for '" .. fluidType .. "'"
    end

    local radioMachine, radCoords, radioErr = chooseRadioForOutput(outRawCoord)
    if not radioMachine then
        return nil, radioErr or "Radio hatch not found for '" .. fluidType .. "'"
    end
    local findedGroup = {fluidType, optFluidRate, neededHatch, radioMachine, thatsHatch, radCoords, outputInterfaceSide, true}
    return findedGroup, nil
end

local function setRadioAllowed(machine, allowed)
    if not machine then
        return
    end
    if machine.setWorkAllowed then
        machine.setWorkAllowed(allowed)
    elseif machine.setEnabled then
        machine.setEnabled(allowed)
    end
end

local function radioKey(machine)
    if not machine then
        return nil
    end
    return machine.address or tostring(machine)
end

local function setRadioForced(machine, forced)
    local key = radioKey(machine)
    if not key then
        return
    end
    if forced then
        radioForcedOff[key] = true
    else
        radioForcedOff[key] = nil
    end
end

local function isRadioForced(machine)
    local key = radioKey(machine)
    return key and radioForcedOff[key] or false
end

local function anyGroupDisabledForRadio(machine)
    for _, group in ipairs(HatchesGroup) do
        if group[4] == machine and group[8] == false then
            return true
        end
    end
    return false
end

local function printMenu(clear)
    if clear then
        term.clear()
    end
    print("Keys:")
    print(" 1 - add group")
    print(" 2 - change rate")
    print(" 3 - disable group")
    print(" 4 - enable group")
    print(" 5 - remove group")
    print(" 6 - list groups")
    print(" 0 - exit program")
end

local function setTextColorSafe(color)
    if term.setTextColor then
        pcall(term.setTextColor, color)
    elseif comp.gpu then
        pcall(comp.gpu.setForeground, color)
    end
end

printError = function(msg)
    setTextColorSafe(0xFF0000)
    print(msg)
    setTextColorSafe(0xFFFFFF)
end

local function printGroups()
    if #HatchesGroup == 0 then
        print("Groups: none")
        return
    end
    local dupes = {}
    for _, group in ipairs(HatchesGroup) do
        local fluid = group[1]
        dupes[fluid] = (dupes[fluid] or 0) + 1
    end
    print("Groups:")
    for i, group in ipairs(HatchesGroup) do
        local enabled = group[8] ~= false
        local line = string.format("  %d) %s | rate=%s | %s", i, tostring(group[1]), tostring(group[2]), enabled and "ON" or "OFF")
        if dupes[group[1]] and dupes[group[1]] > 1 then
            local addr = group[5] and (group[5].address or tostring(group[5])) or "?"
            line = line .. " | tr=" .. tostring(addr)
        end
        print(line)
    end
end

local function promptGroupLoop()
    while true do
        printMenu(true)
        print("Enter Fluid type name:")
        local fluidType = io.read()
        print("Enter optimal fluid rate:")
        local optFluidRate = tonumber(io.read())
        if not optFluidRate then
            printError("Invalid optFluidRate")
        else
            local group, err = buildGroup(fluidType, optFluidRate)
            if group then
                return group
            end
            printError(err)
        end
        print("Press Enter to retry...")
        io.read()
    end
end

local function addGroupInteractive()
    local group = promptGroupLoop()
    table.insert(HatchesGroup, group)
    print("Added group #" .. tostring(#HatchesGroup))
    printMenu(true)
end

local function updateRateInteractive()
    printMenu(true)
    printGroups()
    print("Enter group index:")
    local idx = tonumber(io.read())
    if not idx or not HatchesGroup[idx] then
        print("Group not found")
        return
    end
    print("Enter new optimal fluid rate:")
    local optFluidRate = tonumber(io.read())
    if not optFluidRate then
        print("Invalid optFluidRate")
        return
    end
    HatchesGroup[idx][2] = optFluidRate
    print("Group #" .. tostring(idx) .. " optFluidRate = " .. tostring(optFluidRate))
    printMenu(true)
end

local function disableRadioInteractive()
    printMenu(true)
    printGroups()
    print("Enter group index:")
    local idx = tonumber(io.read())
    if not idx or not HatchesGroup[idx] then
        print("Group not found")
        return
    end
    HatchesGroup[idx][8] = false
    setRadioForced(HatchesGroup[idx][4], true)
    setRadioAllowed(HatchesGroup[idx][4], false)
    print("Group #" .. tostring(idx) .. " radio disabled")
    printMenu(true)
end

local function enableRadioInteractive()
    printMenu(true)
    printGroups()
    print("Enter group index:")
    local idx = tonumber(io.read())
    if not idx or not HatchesGroup[idx] then
        print("Group not found")
        return
    end
    HatchesGroup[idx][8] = true
    if anyGroupDisabledForRadio(HatchesGroup[idx][4]) then
        setRadioForced(HatchesGroup[idx][4], true)
        setRadioAllowed(HatchesGroup[idx][4], false)
    else
        setRadioForced(HatchesGroup[idx][4], false)
        setRadioAllowed(HatchesGroup[idx][4], true)
    end
    print("Group #" .. tostring(idx) .. " radio enabled")
    printMenu(true)
end

local function removeGroupInteractive()
    printMenu(true)
    printGroups()
    print("Enter group index:")
    local idx = tonumber(io.read())
    if not idx or not HatchesGroup[idx] then
        print("Group not found")
        return
    end
    local removedRadio = HatchesGroup[idx][4]
    setRadioAllowed(removedRadio, false)
    table.remove(HatchesGroup, idx)
    if removedRadio then
        if anyGroupDisabledForRadio(removedRadio) then
            setRadioForced(removedRadio, true)
        else
            setRadioForced(removedRadio, false)
        end
    end
    print("Group #" .. tostring(idx) .. " removed")
    printMenu(true)
end

local function listGroupsInteractive()
    printMenu(true)
    printGroups()
end

handleKey = function(char)
    if char == 49 then
        addGroupInteractive()
    elseif char == 50 then
        updateRateInteractive()
    elseif char == 51 then
        disableRadioInteractive()
    elseif char == 52 then
        enableRadioInteractive()
    elseif char == 53 then
        removeGroupInteractive()
    elseif char == 54 then
        listGroupsInteractive()
    elseif char == 48 then
        setRadioAllowed(nil, false)
        term.clear()
        os.exit()
    end
end

while outputHatches ~= 0 do
    local group = promptGroupLoop()
    table.insert(HatchesGroup, group)
    outputHatches = outputHatches - 1
end

printMenu(true)

local function findFluidTank(transposer, fluidType)
    local tanks = transposer.getFluidInTank(tankSide)
    if tanks then
        for _, info in pairs(tanks) do
            if info.label == fluidType then
                return tankSide, info
            end
        end
    end
    return nil, nil
end

local function dumpExcess(transposer, outputSide, excess)
    if not transposer or not outputSide or excess <= 0 then
        return
    end
    transposer.transferFluid(tankSide, outputSide, excess)
end

local function findOutputInterfaceSide(transposer)
    for _, s in ipairs({side.up, side.north, side.south, side.west, side.east}) do
        if transposer.getInventoryName(s) == "tile.fluid_interface" then
            return s
        end
    end
    return nil
end

local function dumpExcessAllTransposers()
    for _, tr in pairs(transLib) do
        local outputSide = findOutputInterfaceSide(tr)
        if outputSide then
            local tanks = tr.getFluidInTank(tankSide)
            if tanks then
                for tankIndex, info in ipairs(tanks) do
                    if info and info.amount and info.capacity then
                        local target = info.capacity * 0.5
                        local excess = (info.amount or 0) - target
                        if excess > 0 then
                            tr.transferFluid(tankSide, outputSide, excess, tankIndex)
                        end
                    end
                end
            end
        end
    end
end

local function waitForAmountChange(transposer, fluidType, lastAmount)
    while true do
        if not interruptableSleep(1) then
            return false
        end
        local _, info = findFluidTank(transposer, fluidType)
        if not info or info.amount ~= lastAmount then
            return true
        end
    end
end

local rateInterval = 1
while true do
    for _, group in pairs(HatchesGroup) do
        local fluidType = group[1]
        local optRate = group[2]
        local radioMachine = group[4]
        local transposer = group[5]
        local outputSide = group[7]
        local enabled = group[8] ~= false

        if isRadioForced(radioMachine) then
            setRadioAllowed(radioMachine, false)
        elseif not enabled then
            setRadioAllowed(radioMachine, false)
        else
            local _, info = findFluidTank(transposer, fluidType)
            if not info or not info.capacity then
                setRadioAllowed(radioMachine, false)
            else
                local amount = info.amount or 0
                local capacity = info.capacity or 0
                local target = capacity * 0.5

                if amount >= target then
                    setRadioAllowed(radioMachine, true)

                    local before = amount
                    if not interruptableSleep(rateInterval) then
                        return
                    end
                    local _, infoAfter = findFluidTank(transposer, fluidType)
                    if infoAfter then
                        local after = infoAfter.amount or 0
                        local output = before - after
                        if output < 0 then
                            output = 0
                        end
                        if output >= optRate then
                            if not waitForAmountChange(transposer, fluidType, after) then
                                return
                            end
                        elseif output < optRate then
                            setRadioAllowed(radioMachine, false)
                        end
                    else
                        setRadioAllowed(radioMachine, false)
                    end
                else
                    setRadioAllowed(radioMachine, false)
                end
            end
        end

    end
    -- Dump excess for all transposers each cycle
    dumpExcessAllTransposers()
    if not interruptableSleep(0.2) then
        return
    end
end
