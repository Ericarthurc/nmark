# Perfomance comparison detail

## How to compare
`./casa build` generates 100 same htmls containing a lot of markdown delimiters. Contents and source code are in my [repo](https://github.com/kyoheiu/Casa).

## result
### nim-markdown@0.8.5 >>
| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./casa build` | 296.1 ± 12.2 | 287.6 | 322.4 | 1.00 |

### nmark@0.1.5>>| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./casa build` | 53.3 ± 1.3 | 51.7 | 56.5 | 1.00 |