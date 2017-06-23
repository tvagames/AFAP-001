
turn = "roll"
releaseTime = 0
lastDest = nil
constInfo = {}
MAX_ALT = 400
MIN_ALT = 100
TILT_ALT = 30

function YawLeft(I, drive)
  I:RequestControl(2,0,drive)
end

function YawRight(I, drive)
  I:RequestControl(2,1,drive)
end

function RollLeft(I, drive)
  I:RequestControl(2,2,drive)
end

function RollRight(I, drive)
  I:RequestControl(2,3,drive)
end

function NoseUp(I, drive)
  I:RequestControl(2,4,drive)
end

function NoseDown(I, drive)
  I:RequestControl(2,5,drive)
end

function Forward(I, drive)
  I:RequestControl(2,8,drive)
end

function AdjustYaw(I, deg, drive)
  if deg > 0 then
    YawRight(I, drive)
  else
    YawLeft(I, drive)
  end
end

function AdjustPitch(I, deg, drive)
  if deg > 0 then
    NoseDown(I, drive)
  else
    NoseUp(I, drive)
  end
end

function AdjustRoll(I, deg, drive)

  if deg > 0 then
    RollRight(I, drive)
  else
    RollLeft(I, drive)
  end
end

function ZeroOrigin(a)
  if a == 0 then
    return 0
  end
  return ((a + 180) % 360) - 180
end

function RadToZeroOrigin(a)
  if a == 0 then
    return 0
  end
  return ((a + Math.PI) % (Math.PI * 2)) - Math.PI
end

function Angle(a, b)
  return math.deg(math.acos(Vector3.Dot(a, b)
 / (Vector3.Magnitude(a) * Vector3.Magnitude(b))))
end

function ToEulerAngle(deg)
  return deg / Mathf.PI * 180
end

function ToLocalPosition(I, t)
  fvec = I:GetConstructForwardVector()
  uvec = I:GetConstructUpVector()
  rvec = I:GetConstructRightVector()

I:Log("fvec" .. fvec:ToString())
  ydeg = ToEulerAngle(Mathf.Atan2(t.z, t.x))
  p = Quaternion.Euler(t) * Quaternion.AngleAxis(ydeg, uvec)

  rdeg = ToEulerAngle(Mathf.Atan2(t.y, t.x))
  p = p * Quaternion.AngleAxis(rdeg, fvec)

  pdeg = ToEulerAngle(Mathf.Atan2(t.z, t.y))
  p = p * Quaternion.AngleAxis(pdeg, rvec)

  I:Log("y=" .. ydeg .. ", r=" .. rdeg .. ", p=" .. pdeg)
  I:LogToHud("p.x=" .. ToEulerAngle(p.x) .. ", p.y=" .. ToEulerAngle(p.y) .. ", p.z=" .. ToEulerAngle(p.z))

  return p
end

function DirectByRollingTo(I, dest)
  pos = constInfo.pos
  t = (dest - pos).normalized
  fvec = I:GetConstructForwardVector()
  uvec = I:GetConstructUpVector()
  rvec = I:GetConstructRightVector()

  lateral = Vector3.Dot(t, rvec)
  longitudinal  = Vector3.Dot(t, fvec)
  vertical = Vector3.Dot(t, uvec)
 -- 下がプラス　上がマイナス

  --tar = ToLocalPosition(I, t)
--[[

  pdeg = ToEulerAngle(tar.y)
  
  r = I:GetConstructRoll()
  roll = ToEulerAngle(r)
  roll = ZeroOrigin(roll)

  p = I:GetConstructPitch()
  pitch = ToEulerAngle(p)
  pitch = ZeroOrigin(pitch)
  if -10 < pdeg and pdeg < 10 then
    AdjustRoll(I, roll, 1)
  else
    AdjustRoll(I, tar.x, 1)
    AdjustPitch(I, tar.y, 1)
  end
--]]

    pitch = ZeroOrigin(I:GetConstructPitch())
    roll = ZeroOrigin(I:GetConstructRoll())

    if longitudinal < -0.9  then
  I:LogToHud("1lateral"..lateral..", vertical"..vertical.. ", longitudinal"..longitudinal)
      if roll > -90 and roll < 90 then
--        AdjustRoll(I, lateral, 1)
        AdjustRoll(I, -1, 1)
      else
        AdjustRoll(I, -roll, 1)
      end

      AdjustPitch(I, -1, 1)
    elseif longitudinal > 0  then
        AdjustRoll(I, roll, 1)
        AdjustPitch(I, -vertical, 1)
        AdjustYaw(I,lateral, 1)

    else
  I:Log("2lateral"..lateral..", vertical"..vertical.. ", longitudinal"..longitudinal)
      if roll > -90 and roll < 90 then
        AdjustRoll(I, lateral, 1)
      else
        AdjustRoll(I, -roll, 1)
      end

  --    AdjustPitch(I, -vertical, 1)
      AdjustPitch(I, -pitch, 1)
    end

--    AdjustRoll(I, -roll, 1)
--    AdjustPitch(I, -pitch, 1)
--    AdjustYaw(I,lateral, 1)

end

function DirectByYawringTo(I, dest)
  pos = constInfo.pos
  v = I:GetConstructForwardVector()
  t = dest - pos 
  vdeg = Mathf.Atan2(v.x, v.z)
  tdeg = Mathf.Atan2(t.x, t.z)
  deg =  tdeg- vdeg
  I:Log("vdeg=" .. tdeg)
  I:Log("tdeg=" .. vdeg)
  I:Log("deg=" .. deg)
  AdjustYaw(I, deg, 1)

  roll = I:GetConstructRoll()
  roll = ZeroOrigin(roll) / 180
  AdjustRoll(I, roll, 1)
  I:Log("roll=" .. roll)

  I:Log("ty=" .. t.y)
  I:Log("my=" .. pos.y )

  if t.y < 100 then
    t.y = 100
  end

  pitch = ZeroOrigin(I:GetConstructPitch())

  thol = t
  vt = v - t
  I:Log("pitch=" .. pitch)
  I:Log("vt=" .. vt:ToString())
  thol.x = t.x
  thol.y = pos.y
  thol.z = t.z
  a = Angle(t, thol)
  AdjustPitch(I, a - pitch, 1)
end

function DirectTo(I, dest)
  if turn == "roll" then
    DirectByRollingTo(I, dest)
  else
    DirectByYawringTo(I, dest)
  end
end

function Cramp(val, max, min)
  if val < min then
    return min
  elseif val > max then
    return max
  else
    return val
  end
end

function Update(I)

  I:ClearLogs()
  constInfo.pos = I:GetConstructPosition()
  pos = constInfo.pos
  if lastDest == nil then
    lastDest = pos
  end
  I:Log(pos:ToString())
  drive = 1
  if I:IsDocked() then
    drive = 0
    releaseTime = 0
  elseif releaseTime == 0 then
    releaseTime = I:GetTime()
  end

  fc = I:GetFriendlyCount()
  tc = I:GetNumberOfTargets(0)
  dest = lastDest
  if tc > 0 then
    ti = I:GetTargetInfo(0, 0)
    tpi = I:GetTargetPositionInfo(0, 0)
    I:Log("tpi="..tpi.Direction:ToString())
    I:Log("tpie="..tpi.Elevation)
    tp = ti.Position
    tp.y = tp.y + 50
    tp.y = Cramp(tp.y, MAX_ALT, MIN_ALT)
    dest = tp
    lastDest = dest
  
  elseif fc > 0 then
    c = I:GetFriendlyCount()
    fi = I:GetFriendlyInfo(0)
    fp = fi.ReferencePosition
    fp.y = 300
    fp.x = 10
    fp.z = 10
    fp.y = Cramp(fp.y, MAX_ALT, MIN_ALT)
    dest = fp
    lastDest = dest
  else
    dest.y = Cramp(dest.y, MAX_ALT, MIN_ALT)
  end

  DirectTo(I, dest)
  Forward(I, drive)

  I:Log("dest =" .. dest:ToString())
  
  sc = I:GetSpinnerCount()
  for si = 0, sc - 1, 1 do
    s = I:GetSpinnerInfo(si)

    if I:IsSpinnerDedicatedHelispinner(si) then
      I:SetSpinnerInstaSpin(si, drive)
      if pos.y < TILT_ALT then
        I:SetDedicatedHelispinnerUpFraction(si,0.5)
      else
        I:SetDedicatedHelispinnerUpFraction(si,0)
      end
    elseif pos.y < TILT_ALT then
      if s.LocalPosition.x > 0 then
        I:SetSpinnerRotationAngle(si, -90)
      else
        I:SetSpinnerRotationAngle(si, 90)
      end
    else
      I:SetSpinnerRotationAngle(si, 0)
    end
  end
end
