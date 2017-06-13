class PlayerHealgunHusk : PlayerGunHusk
{
	UnitPtr m_target;

	bool m_attackDown;
	bool m_attackDownPrev;

	string m_holdFx;
	UnitPtr m_holdFxUnit;

	float m_shaftRange;

	SoundEvent@ m_holdLoopSound;
	SoundEvent@ m_holdEndSound;
	SoundInstance@ m_holdLoopSoundI;

	float m_teamDmg;

	HitscanShooter@ m_shooter;
	HitscanShooter@ m_fakeShooter;

	PlayerHealgunHusk(UnitPtr owner, SValue& params)
	{
		super(owner, params);

		m_holdFx = GetParamString(owner, params, "beam-fx");
		m_shaftRange = GetParamFloat(owner, params, "beam-range");

		@m_holdLoopSound = Resources::GetSoundEvent(GetParamString(owner, params, "beam-loop-snd", false));
		@m_holdEndSound = Resources::GetSoundEvent(GetParamString(owner, params, "beam-end-snd", false));

		auto hitFx = GetParamString(owner, params, "beam-hit-fx", false);
		auto hitEffects = LoadEffects(owner, params, "beam-hit-");
		@m_shooter = HitscanShooter(hitEffects, null, hitFx, "", false);
		@m_fakeShooter = HitscanShooter(null, null, hitFx, "", false);
	}

	void Initialize(string path) override
	{
		PlayerGunHusk::Initialize(path);

		PropagateWeaponInformation(m_shooter.m_hitEffects, m_weaponIdHash);
		PropagateWeaponInformation(m_shooter.m_missEffects, m_weaponIdHash);
		PropagateWeaponInformation(m_fakeShooter.m_hitEffects, m_weaponIdHash);
		PropagateWeaponInformation(m_fakeShooter.m_missEffects, m_weaponIdHash);
	}

	float offsetZ = 70;

	void StartBeam(UnitPtr target)
	{
		if (m_holdFxUnit.IsValid())
			StopBeam();

		m_target = target;

		Actor@ actor = cast<Actor>(target.GetScriptBehavior());
		if (actor is null)
		{
			PrintError("Healgun target '" + target.GetDebugName() + "' is not an actor!");
			return;
		}

		vec3 pos = m_plrHusk.m_unit.GetPosition();
		pos.y -= Tweak::PlayerCameraHeight;

		vec2 actorPos = xy(target.GetPosition());
		vec2 playerPos = xy(pos);

		vec2 actorDir = normalize(actorPos - playerPos);
		m_holdDir = m_holdDirNext = atan(actorDir.y, actorDir.x);
		m_holdLength = m_holdLengthNext = dist(playerPos, actorPos);

		dictionary ePs = { { 'angle', m_holdDir }, { 'length', m_holdLength } };
		m_holdFxUnit = PlayEffect(m_holdFx, xy(pos), ePs);
		auto behavior = cast<EffectBehavior>(m_holdFxUnit.GetScriptBehavior());
		behavior.m_looping = true;

		if (m_holdLoopSound !is null)
		{
			@m_holdLoopSoundI = m_holdLoopSound.PlayTracked(pos + vec3(0, 0, offsetZ));
			m_holdLoopSoundI.SetPaused(false);
		}
	}

	void StopBeam()
	{
		if (!m_holdFxUnit.IsValid())
			return;

		if (!m_holdFxUnit.IsDestroyed())
			m_holdFxUnit.Destroy();
		m_holdFxUnit = UnitPtr();

		if (m_holdLoopSoundI !is null)
			m_holdLoopSoundI.Stop();
		@m_holdLoopSoundI = null;

		m_target = UnitPtr();
	}

	void Update(int dt, vec2 dir) override
	{
		PlayerGunHusk::Update(dt, dir);

		if (m_target.IsValid())
		{
			vec2 actorPos = xy(m_target.GetPosition());
			vec2 playerPos = xy(m_plrHusk.m_unit.GetPosition());
			playerPos.y -= Tweak::PlayerCameraHeight;

			vec2 actorDir = normalize(actorPos - playerPos);

			m_holdDir = m_holdDirNext;
			m_holdLength = m_holdLengthNext;

			m_holdDirNext = atan(actorDir.y, actorDir.x);
			m_holdLengthNext = dist(playerPos, actorPos);

			// deal with 360 to 0 wrapping
			if (abs(m_holdDirNext - m_holdDir) > PI / 2.0)
				m_holdDir = m_holdDirNext;
		}
	}

	void PreRender(int idt) override
	{
		float mul = idt / 33.0;

		vec3 pos = m_plrHusk.m_unit.GetInterpolatedPosition(idt);
		if (m_holdFxUnit.IsValid() && !m_holdFxUnit.IsDestroyed())
		{
			pos.y -= Tweak::PlayerCameraHeight;
			m_holdFxUnit.SetPosition(pos.x, pos.y, pos.z);

			auto behavior = cast<EffectBehavior>(m_holdFxUnit.GetScriptBehavior());
			if (behavior !is null)
			{
				behavior.SetParam("angle", lerp(m_holdDir, m_holdDirNext, mul));
				behavior.SetParam("length", lerp(m_holdLength, m_holdLengthNext, mul));
			}
		}
	}
}
