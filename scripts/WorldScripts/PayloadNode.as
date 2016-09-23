namespace WorldScript
{
	[WorldScript color="255 180 170" icon="system/icons.png;416;128;32;32"]
	class PayloadNode
	{
		vec3 Position;

		[Editable]
		UnitFeed NextNode;

		[Editable]
		bool Checkpoint;

		PayloadNode@ m_prevNode;
		PayloadNode@ m_nextNode;
		float m_locationFactor;

		SValue@ ServerExecute()
		{
			return null;
		}
	}
}
