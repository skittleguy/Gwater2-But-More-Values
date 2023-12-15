#pragma once
#include <math.h>
// Float structures originally provided by AndrewEathan (https://mariluu.hehe.moe/)

//Float4 structure, holds 4 floats, X, Y, Z, and W
struct float4 {
	float x, y, z, w;
	float4(float x1, float y1, float z1, float w1) : x(x1), y(y1), z(z1), w(w1) {};
	float4() : x(0), y(0), z(0), w(0) {};
	float4(float l) : x(l), y(l), z(l), w(l) {};
	//float4(Vector l, float w1) : x(l.x), y(l.y), z(l.z), w(w1) {};
	float4 operator+(float4 e) {
		return { x + e.x, y + e.y, z + e.z, w + e.w };
	}
	float4 operator*(float e) {
		return { x * e, y * e, z * e, w * e };
	}
};

//Float3 structure, holds 3 floats, X, Y, and Z
struct float3 {
	float x, y, z;
	float3(float x1, float y1, float z1) : x(x1), y(y1), z(z1) {};
	float3() : x(0), y(0), z(0) {};
	float3(float l) : x(l), y(l), z(l) {};
	//float3(Vector l) : x(l.x), y(l.y), z(l.z) {};
	//float3(float4 l) : x(l.x), y(l.y), z(l.z) {};
	float3 operator+(float3 e) {
		return { x + e.x, y + e.y, z + e.z };
	}
	float3 operator*(float3 e) {
		return { x * e.x, y * e.y, z * e.z };
	}
	float3 operator-(float3 e) {
		return { x - e.x, y - e.y, z - e.z };
	}
	float3 operator/(float e) {
		return { x / e, y / e, z / e };
	}
	float3 operator-() {
		return { -x, -y, -z };
	}
	bool operator==(float3 e) {
		return (x == e.x && y == e.y && z == e.z);
	}
	bool operator!=(float3 e) {
		return (x != e.x || y != e.y || z != e.z);
	}
};

inline float Dot(float3 a, float3 b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

inline float3 Cross(float3 A, float3 B) {
	return float3(
		A.y * B.z - A.z * B.y,
		A.z * B.x - A.x * B.z,
		A.x * B.y - A.y * B.x
	);
}

inline float3 Normalize(float3 a) {
	return a / sqrt(Dot(a, a));
}

/*
inline Vector Vec3(float4 input) {
	Vector v = Vector();
	v.x = input.x; v.y = input.y; v.z = input.z;
	return v;
}*/

