# Complex argument and result ABI

The first complex slice covers component extraction, conjugation,
projection, magnitude and argument in all three floating formats.
The component operations preserve the binary representation of
each retained component, including signed zero and NaN payloads.
Projection of a complex infinity produces positive real infinity and
an imaginary zero with the original imaginary sign.

A float complex value uses the low 64 bits of XMM0 with real in the
low word and imaginary in the high word. Double complex uses XMM0
for real and XMM1 for imaginary. A long double complex argument
uses two consecutive 16-byte stack slots. Its return places real
in ST0 and imaginary in ST1. Only the ten value bytes of each
extended slot are read. Real results use the usual scalar return
register. [System V AMD64 ABI](https://gitlab.com/x86-psABIs/x86-64-ABI/-/blob/master/x86-64-ABI/low-level-sys-info.tex).

Magnitude uses the exact sum-of-squares and square-root rounding
contract. Argument uses the quadrant and signed-zero contract of
atan2 with imaginary first and real second. The remaining complex
arithmetic needs branch-cut and special-value matrices before it
can join the independent numerical gate.

Complex logarithm uses an exact dyadic squared magnitude before
the logarithm. This preserves a tiny real component when the
squared magnitude lies near one. Its imaginary component follows
the signed branch cut of the argument. Complex square root uses
the nonnegative real branch and takes the imaginary sign from
the input. It computes the larger component from an exact scaled
sum of squares and obtains the smaller component as the ratio
of the original imaginary magnitude to twice the larger component.
This keeps the small component through both intermediate range
loss and subtraction cancellation. Range effects describe the
final components and preserve the caller's floating control state.

Complex exponential scales a common unrounded exponential by
unrounded sine and cosine factors before target-format rounding.
For tiny inputs it compares the exact dyadic terms that determine
the rounding directions of both components. The floating exception
and errno effects follow the rounded components, including cases
where a small factor rescues a finite result.

Complex sine, cosine and their hyperbolic counterparts multiply
unrounded circular and hyperbolic factors. The implementation
keeps each factor's binary scale separate until the final
rounding. For pairs of tiny arguments, exact dyadic comparisons
determine which side of the leading product the true result
lies on. Axis and nonfinite cases follow the signed-zero and
infinity rules in C17 Annex G.

Complex tangent uses a sum of squares in the denominator, which
keeps the denominator positive near an imaginary-axis pole of
hyperbolic tangent. For a large hyperbolic argument it uses a
separately scaled negative exponential to retain a tiny
imaginary component. The real component tends to a signed one
with its rounding direction determined before the limit is
rounded. Complex tangent and hyperbolic tangent share these
formulas through a component exchange.

Complex inverse tangent uses an exact dyadic squared magnitude.
For the hyperbolic form, the imaginary component is half the
angle of (1-|z|^2+2i,operatorname{Im}z). The real component
uses the log of the ratio of the squared distances to the two
real branch points. The small-ratio path retains the leading
dyadic ratio and its correction direction to avoid cancellation.
The circular form exchanges the axes before and after this
kernel.

Complex inverse sine, cosine and their hyperbolic forms derive
the components from distances to the two real branch points.
When a distance nearly equals its real projection, the kernel
forms the difference as an exact squared imaginary magnitude
over a sum. Each positive sum, square root and quotient carries
a binary scale independently of its significand. Angle
quadrants and signs are selected before target-format rounding.

The zero-real cacosh case with a NaN imaginary input has a
quiet NaN real result and an imaginary magnitude of pi over two.
The imaginary sign is unspecified. This follows the correction
incorporated in C17. [WG14 DR 471](https://open-std.org/JTC1/SC22/WG14/issues/c11c17/log.html#issue0471).

Complex power uses the principal logarithm of the base. Its
phase precision grows with the magnitude of the exponent before
the sine and cosine reduction. Pure real and imaginary bases
retain their exact angular quadrant where the exponent permits
an exact reduction. The SysV binary-argument ABI uses XMM0 and
XMM1 for packed float complex operands, XMM0 through XMM3 for
double complex operands, or four consecutive stack slots for
extended complex operands.

The power kernel chooses at least 640 fractional bits and adds
guard bits according to the larger exponent component. It
evaluates the logarithm and angle series in blocks and keeps
small residuals at a separate scale. Multiples of pi over four
are reduced from the exponent's exact dyadic representation.
For the remaining phase, Payne–Hanek reduction preserves a
small residual as a scaled integer. Directed MPFR enclosures
check the 17,408-bit constant floors. The resulting error
claims apply to the measured vectors and controlled cases in
the independent gate.
