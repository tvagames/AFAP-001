turn = "roll"
releaseTime = 0
lastDest = nil
constInfo = {}
MAX_ALT = 400 -- 最大高度
MIN_ALT = 100 -- 最小高度
CLOSE_LIMIT = 50 -- 最接近距離
MAX_ROLL_ANGLE = 120 -- 最大ロール角
IS_TILT_ROTOR = false -- ティルトローター機か否か
TILT_ALT = 30 -- ティルト調整が必要な高度
IS_SUB_VEHICLE = false -- サブビークルか否か
FORWARD_VECTOR = 1 -- デディブレ用パラメータ。1：normal, -1：reverse

--------------------
-- 0～360を-180～180に変換（オイラー）
--------------------
function ZeroOrigin(a)
  if a == 0 then
    return 0
  end
  return ((a + 180) % 360) - 180
end

--------------------
-- 0～360を-180～180に変換（ラディアン）
--------------------
function RadToZeroOrigin(a)
  if a == 0 then
    return 0
  end
  return ((a + Math.PI) % (Math.PI * 2)) - Math.PI
end

--------------------
-- 二つのベクトルのなす角
--------------------
function Angle(a, b)
  return math.deg(math.acos(Vector3.Dot(a, b)
 / (Vector3.Magnitude(a) * Vector3.Magnitude(b))))
end

--------------------
-- ラディアンをオイラー角に変換
--------------------
function ToEulerAngle(deg)
  return deg / Mathf.PI * 180
end

--------------------
-- 範囲内にあるか否か
--------------------
function IsInOfRange(actual, min, max)
  return (min <= actual and actual <= max)
end

--------------------
-- 範囲外にあるか否か
--------------------
function IsOutOfRange(actual, min, max)
  return (IsInOfRange(actual, min, max) == false)
end

--------------------
-- 範囲内に丸める
--------------------
function Clamp(val, min, max)
  if val < min then
    return min
  elseif val > max then
    return max
  else
    return val
  end
end

--------------------
-- 左ヨー
--------------------
function YawLeft(I, drive)
  I:RequestControl(2,0,drive)
end

--------------------
-- 右ヨー
--------------------
function YawRight(I, drive)
  I:RequestControl(2,1,drive)
end

--------------------
-- 左ロール
--------------------
function RollLeft(I, drive)
  I:RequestControl(2,2,drive)
end

--------------------
-- 右ロール
--------------------
function RollRight(I, drive)
  I:RequestControl(2,3,drive)
end

--------------------
-- 機首上げ
--------------------
function NoseUp(I, drive)
  I:RequestControl(2,4,drive)
end

--------------------
-- 機首下げ
--------------------
function NoseDown(I, drive)
  I:RequestControl(2,5,drive)
end

--------------------
-- 前へ
--------------------
function Forward(I, drive)
  if IS_SUB_VEHICLE and I:IsDocked() then
    return 
  end
  sc = I:GetSpinnerCount()
  for si = 0, sc - 1, 1 do
    if I:IsSpinnerDedicatedHelispinner(si) then
      I:SetSpinnerInstaSpin(si, drive * FORWARD_VECTOR)
    end      
  end
  --I:RequestControl(2,8,drive)
end

--------------------
-- ティルト調整
--------------------
function AdjustTilt(I, pos)
  sc = I:GetSpinnerCount()
  for si = 0, sc - 1, 1 do
    s = I:GetSpinnerInfo(si)

    if I:IsSpinnerDedicatedHelispinner(si) then
      
      if IS_TILT_ROTOR then
        if pos.y < TILT_ALT then
          I:SetDedicatedHelispinnerUpFraction(si,0.5)
        else
          I:SetDedicatedHelispinnerUpFraction(si,0)
        end
      end
    elseif IS_TILT_ROTOR and pos.y < TILT_ALT then
      if s.LocalPosition.x > 0 then
        I:SetSpinnerRotationAngle(si, -MAX_ROLL_ANGLE)
      else
        I:SetSpinnerRotationAngle(si, MAX_ROLL_ANGLE)
      end
    elseif IS_TILT_ROTOR then
      I:SetSpinnerRotationAngle(si, 0)
    end
  end

end

--------------------
-- ヨー調整
--------------------
function AdjustYaw(I, deg, drive)
  if deg > 0 then
    YawRight(I, drive)
  else
    YawLeft(I, drive)
  end
end

--------------------
-- ピッチ調整
--------------------
function AdjustPitch(I, deg, drive)
  if deg > 0 then
    NoseDown(I, drive)
  else
    NoseUp(I, drive)
  end
end

--------------------
-- ロール調整
--------------------
function AdjustRoll(I, deg, drive)

  if deg > 0 then
    RollRight(I, drive)
  else
    RollLeft(I, drive)
  end
end

--------------------
-- 自分から見た目標の位置
--------------------
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

--------------------
-- 衝突しそうか否か
--------------------
function IsAlmostCrash(I, tpi)
  dest = tpi.Position
  distance = tpi.Range

  if distance > 200 then
    -- 距離あるし大丈夫（慢心）
    return false
  end

  pos = constInfo.pos
  t = (dest - pos).normalized

  fvec = I:GetConstructForwardVector()
  -- 前がプラス　後ろがマイナス
  longitudinal  = Vector3.Dot(t, fvec)

  if longitudinal < 0 and distance > 20  then
    -- 目標が後ろにいるから大丈夫
    return false
  end
  
  -- 円錐状に20度以内にいたら当たるかも
  angle = Angle(t, fvec)

  fromTarget = (pos - dest).normalized
  targetDir = tpi.Direction
  fromTargetLongitudinal  = Vector3.Dot(fromTarget, targetDir)
  if fromTargetLongitudinal < 0 then
    -- 敵の後ろにいる
    if longitudinal > 0 and distance < CLOSE_LIMIT and angle < 30 then
      -- 前20mは逃げる
      return true
    end
  else
    -- 敵の前にいる
    if longitudinal > 0 and distance < CLOSE_LIMIT then
      -- 前50mは逃げる
      return true
    end
  end

  return angle < 30 
end

--------------------
-- 〔進行方向を変えて障害物を〕避ける、迂回する
-- 【レベル】11、【発音】sə̀ːrkəmvént、
-- 【＠】サーカムベント、サーカンベント、
-- 【変化】《動》circumvents ｜ circumventing ｜ circumvented、【分節】cir・cum・vent
--------------------
function Circumvent(I, dest)
  pos = constInfo.pos
  t = (dest - pos).normalized
  fvec = I:GetConstructForwardVector()
  uvec = I:GetConstructUpVector()
  rvec = I:GetConstructRightVector()

  lateral = Vector3.Dot(t, rvec)
  longitudinal  = Vector3.Dot(t, fvec)
  vertical = Vector3.Dot(t, uvec)


  roll = ZeroOrigin(I:GetConstructRoll())
  if IsInOfRange(roll, -MAX_ROLL_ANGLE, MAX_ROLL_ANGLE) then
    if lateral < 0 then
      -- 左にいるから右に逃げる
      AdjustRoll(I, 1, 1)
      I:LogToHud("左にいるから右に逃げる")
    else
      -- 右にいるから左に逃げる
      AdjustRoll(I, -1, 1)
      I:LogToHud("右にいるから左に逃げる")
    end
  else
    AdjustRoll(I, -roll, 1)
      I:LogToHud("逃げたいけどロール安定優先")
  end
  
    AdjustPitch(I, -1, 1)
end

--------------------
-- ロールで方向制御
--------------------
function DirectByRollingTo(I, dest)
  pos = constInfo.pos
  t = (dest - pos).normalized
  fvec = I:GetConstructForwardVector()
  uvec = I:GetConstructUpVector()
  rvec = I:GetConstructRightVector()

 -- 右がプラス　左がマイナス
  lateral = Vector3.Dot(t, rvec)
 -- 前がプラス　後ろがマイナス
  longitudinal  = Vector3.Dot(t, fvec)
 -- 下がプラス　上がマイナス
  vertical = Vector3.Dot(t, uvec)

  pitch = ZeroOrigin(I:GetConstructPitch())
  roll = ZeroOrigin(I:GetConstructRoll())

  if longitudinal < -0.5  then
    -- 目標が後ろにいる

    -- 目標に対するロール角
--    tarRollDeg = ToEulerAngle(Mathf.Atan2(lateral, vertical))

    if pos.y >= MIN_ALT and IsInOfRange(roll, -MAX_ROLL_ANGLE, MAX_ROLL_ANGLE) then
--        AdjustRoll(I, lateral, 1)
      -- とりあえず左に
    I:LogToHud("DirectByRollingTo 1.1 lateral"..lateral..", vertical"..vertical.. ", longitudinal"..longitudinal)
      AdjustRoll(I, -1, 1)
    else
    I:LogToHud("DirectByRollingTo 1.2 lateral"..lateral..", vertical"..vertical.. ", longitudinal"..longitudinal)
      AdjustRoll(I, roll, 1)
    end
  
    -- 旋回戦のためロールさせてからピッチ動作
    if pos.y < MIN_ALT or IsInOfRange(roll, -MAX_ROLL_ANGLE-10, -MAX_ROLL_ANGLE+10) or IsInOfRange(roll, MAX_ROLL_ANGLE-10, MAX_ROLL_ANGLE+10) then
      AdjustPitch(I, -1, 1)
    end

  elseif longitudinal > -0.5  then
    -- 目標が前にいる
    I:LogToHud("DirectByRollingTo 2 lateral"..lateral..", vertical"..vertical.. ", longitudinal"..longitudinal)
      AdjustRoll(I, roll, 1)
      AdjustPitch(I, -vertical, 1)
      AdjustYaw(I,lateral, 1)

  else
    -- 目標が真横や真上や真下にいる
    I:LogToHud("DirectByRollingTo 3 lateral"..lateral..", vertical"..vertical.. ", longitudinal"..longitudinal)
    if IsInOfRange(roll, -MAX_ROLL_ANGLE, MAX_ROLL_ANGLE) then
      AdjustRoll(I, lateral, 1)
    else
      AdjustRoll(I, roll, 1)
    end

--    AdjustPitch(I, -vertical, 1)
    AdjustPitch(I, -pitch, 1)
  end

--    AdjustRoll(I, -roll, 1)
--    AdjustPitch(I, -pitch, 1)
--    AdjustYaw(I,lateral, 1)

end

--------------------
-- ヨーで方向制御
--------------------
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

--------------------
-- 方向制御
--------------------
function DirectTo(I, dest)
  if turn == "roll" then
    DirectByRollingTo(I, dest)
  else
    DirectByYawringTo(I, dest)
  end
end

--------------------
-- FromTheDepths
--------------------
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
    -- 敵がいるとき
    ti = I:GetTargetInfo(0, 0)
    tpi = I:GetTargetPositionInfo(0, 0)
    I:Log("tpi="..tpi.Direction:ToString())
    I:Log("tpie="..tpi.Elevation)
    tp = ti.Position -- - (tpi.Direction.normalized * 50)
    tp.y = Clamp(tp.y, MIN_ALT, MAX_ALT-50)
    dest = tp
    lastDest = desta
    if IsAlmostCrash(I, tpi) then
      Circumvent(I, ti.Position)
    else
      DirectTo(I, dest)
    end
  
  elseif fc > 0 then
    -- 敵はいないけど味方がいるときは味方にまとわりつく
    c = I:GetFriendlyCount()
    fi = I:GetFriendlyInfo(0)
    fp = fi.ReferencePosition
    fp.y = 300
    fp.x = 10
    fp.z = 10
    fp.y = Clamp(fp.y, MIN_ALT, MAX_ALT)
    dest = fp
    lastDest = dest
    DirectTo(I, dest)
  else
    dest.y = Clamp(dest.y, MIN_ALT, MAX_ALT)
    DirectTo(I, dest)
  end

  -- 立ち止まるんじゃねぇぞ
  Forward(I, drive)

  I:Log("dest =" .. dest:ToString())

  -- ティルトローター用
  AdjustTilt(I, pos)

end
