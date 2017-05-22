class PlayerHealgunHusk : PlayerGunHusk, IContinuousGun
{
	bool m_attackDown;
	bool m_attackDownPrev;

	float m_shootingIntensity;

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

		m_holdFx = GetParamString(owner, params, "hold-fx");
		m_shaftRange = GetParamFloat(owner, params, "shaft-range");

		@m_holdLoopSound = Resources::GetSoundEvent(GetParamString(owner, params, "hold-loop-snd", false));
		@m_holdEndSound = Resources::GetSoundEvent(GetParamString(owner, params, "hold-end-snd", false));

		m_teamDmg = GetParamFloat(owner, params, "team-dmg", false, 0);

		auto hitFx = GetParamString(owner, params, "shaft-hit-fx", false);
		auto hitEffects = LoadEffects(owner, params, "shaft-hit-");
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


	void ChangeIntensity(float intensity) { m_shootingIntensity = intensity; }

	void StartShooting(int ammo)
	{
		m_plrHusk.m_record.SetAmmo(m_ammoType, ammo);
		m_attackDown = true;
	}

	void StopShooting(int ammo)
	{
		m_plrHusk.m_record.SetAmmo(m_ammoType, ammo);
		StopShaft();
	}

	void StopShaft()
	{
		m_attackDown = false;

		if (m_holdFxUnit.IsValid())
		{
			if (!m_holdFxUnit.IsDestroyed())
				m_holdFxUnit.Destroy();
			m_holdFxUnit = UnitPtr();
		}

		if (m_holdLoopSoundI !is null)
		{
			m_holdLoopSoundI.Stop();
			@m_holdLoopSoundI = null;

			if (m_holdEndSound !is null)
			{
				vec3 pos = xyz(m_plrHusk.m_posTarget);
				pos.y -= Tweak::PlayerCameraHeight;

				PlaySound3D(m_holdEndSound, pos);
			}
		}
	}

	void Update(int dt, vec2 dir) override
	{
		bool attackPressed = false;

		if (m_attackDown && !m_attackDownPrev)
			attackPressed = true;

		m_attackDownPrev = m_attackDown;

		float facing = atan(dir.y, dir.x);
		vec3 pos = xyz(m_plrHusk.m_posTarget);
		pos.y -= Tweak::PlayerCameraHeight;

		if (m_cooldownCount > 0)
			m_cooldownCount -= dt;

		if (m_attackDown)
		{
			if (m_holdLoopSoundI is null && m_holdLoopSound !is null)
			{
				@m_holdLoopSoundI = m_holdLoopSound.PlayTracked(pos);
				m_holdLoopSoundI.SetLooped(true);
				m_holdLoopSoundI.SetPaused(false);
			}

			float aimLength = m_shaftRange;
			vec2 from = xy(pos); // + vec2(0, Tweak::PlayerCameraHeight);
			vec2 endPos = from + dir * aimLength;

			if (m_cooldownCount <= 0)
			{
				endPos = m_shooter.ShootHitscan(m_plrHusk, from, endPos, 0, m_shootingIntensity, m_teamDmg, true);
				m_cooldownCount = m_shootCooldown;
			}
			else
				endPos = m_fakeShooter.ShootHitscan(m_plrHusk, from, endPos, 0, 0, m_teamDmg, true);


			aimLength = length(endPos - from);

			if (GetInput().Attack.Pressed)
			{
				m_holdDir = facing;
				m_holdLength = aimLength;
			}
			else
			{
				m_holdDir = m_holdDirNext;
				m_holdLength = m_holdLengthNext;
			}

			m_holdDirNext = facing;
			m_holdLengthNext = aimLength;

			// deal with 360 to 0 wrapping
			if (abs(m_holdDirNext - m_holdDir) > PI / 2.0)
				m_holdDir = facing;

			if (!m_holdFxUnit.IsValid())
			{
				dictionary ePs = { { 'angle', facing }, { 'length', aimLength } };
				m_holdFxUnit = PlayEffect(m_holdFx, xy(pos), ePs);
				auto behavior = cast<EffectBehavior>(m_holdFxUnit.GetScriptBehavior());
				behavior.m_looping = true;
			}
			else
			{
				if (!m_holdFxUnit.IsDestroyed())
				{
					auto behavior = cast<EffectBehavior>(m_holdFxUnit.GetScriptBehavior());
					if (behavior !is null)
					{
						behavior.SetParam("angle", facing);
						behavior.SetParam("length", aimLength);
					}
				}
			}

			m_currAnim = (m_currAnim + 1) % m_anims.get_length();
			m_plrHusk.SetShootingAnim(m_anims[m_currAnim].GetSceneName(facing), false);
		}

		if (!m_attackDown)
		{
			StopShaft();
			m_plrHusk.SetShootingAnim(m_idleAnim.GetSceneName(facing), false);
		}
		else
		{
			if (m_holdLoopSoundI !is null)
				m_holdLoopSoundI.SetPosition(pos);
		}
	}

	void PreRender(int idt) override
	{
		float mul = idt / 33.0;

		vec3 pos = m_plrHusk.m_unit.GetInterpolatedPosition(idt);
		if (m_holdFxUnit.IsValid() and !m_holdFxUnit.IsDestroyed())
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
