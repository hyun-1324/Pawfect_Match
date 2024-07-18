package utils

func OrderPair(a, b int) (int, int) {
	if a < b {
		return a, b
	} else {
		return b, a
	}
}

func Abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
