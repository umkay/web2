module Parser where

import Data.Char (isSpace)

import Types
import Parse

comma_ = token $ char ','
symbol_ = char '\'' *> (many (digit <|> alpha <|> anyChar "_"))
hole_ = token $ char '_'
q_ = (NVal <$> ((NTNamed <$> symbol_) <|> (NTInt <$> int_)))
     <|> (NVar <$> identifier)
     <|> (pure NHole <* hole_)
rel_ = token $ L <$> identifier
dotrel_ = char '.' *> rel_
hashrel_ = char '#' *> rel_
ineq_ =
  (token (string "=") *> return QEq) <|>
  (token (string "/=") *> return QDisEq) <|>
  (token (string "<") *> return QLess) <|>
  (token (string ">") *> return QMore)
qbin_ = token $ flip QBinOp <$> token expr_ <*> ineq_ <*> token expr_
single_ = (char '@' *> pure Unique) <|> (pure NonUnique)
ep_ lin = token $ EP lin <$> single_ <*> rel_ <*> sepBy flex q_

query_ = token $ Query Low <$> ep_ NonLinear
dotquery_ = token $ string "." *> (Query High <$> ep_ NonLinear)
linearquery_ = token $ string ".." *> (Query Low <$> ep_ Linear)
dotlinearquery_ = token $ string "..." *> (Query High <$> ep_ Linear)
countquery_ = token . bracket_ $ Counter <$> names_ <* sep <*> lhs_
  where
    sep = token (char '|')
    names_ = token $ sepBy1 flex identifier

clause_ = qbin_ <|> dotquery_ <|> linearquery_ <|> dotlinearquery_ <|> query_ <|> countquery_
lhs_ = sepBy1 comma_ clause_

arrow_ = token $ string "=>"
wrap_ p = (token $ char '(') *> token p <* (token $ char ')')
bracket_ p = (token $ char '[') *> token p <* (token $ char ']')

binOp_ =
  (token (char '+') *> return Sum)
  <|> (token (char '*') *> return Mul)
  <|> (token (char '-') *> return Sub)
expr_ =
  (ELit <$> int_)
  <|> (EVar <$> identifier)
  <|> (ENamed <$> symbol_)
  <|> (wrap_ $ flip EBinOp <$> token expr_ <*> binOp_ <*> token expr_)
  <|> (pure EHole <* hole_)

-- allow trailing whitespace?
rquery_ = token $ Assert <$> rel_ <*> sepBy flex expr_
rclause_ = rquery_
rhs_ = (sepBy comma_ rclause_)


rule_ = ws *> (Rule <$> (token lhs_) <*> (arrow_ *> rhs_))

parse s =
  case runParser rule_ s of
    Right (r, "") -> r
    p -> error $ "bad parse: " ++ show p

filterComment = filter (not . null) . map (takeWhile (/= '#')) . lines

readRules f = do
  rs <- filterComment <$> readFile f
  return $ map parse rs